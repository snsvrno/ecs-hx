package ecs.macro;

#if macro

/**
 * creates an empty instance function field
 *
 * @param name the name of the function
 * @param isPrivate if the function is private
 */
function createFunctionField(name : String, ?isPrivate = false) : haxe.macro.Expr.Field {
	var access : Array<haxe.macro.Expr.Access> = [];
	if (isPrivate) access.push(APrivate) else access.push(APublic);
	return {
		name: name,
		access: access,
		pos: haxe.macro.Context.currentPos(),
		kind: FFun({
			args: [],
			expr: macro {

			},
		}),
	};
}

function setArgs(field : haxe.macro.Expr.Field, ... args : haxe.macro.Expr.FunctionArg) {
	switch(field.kind) {
		case FFun(f):
			f.args = args.toArray();
		default:
	}
}

/**
 * inserts the expressions into the field at the end of hte function.
 *
 * @param field the field to inject into, must be a `FFun`
 * @param atBeginning should this be injected at the beginning of the function, defaults to false
 * @param expr the expression(s) to inject.
 */
function inject(field : haxe.macro.Expr.Field, ?atBeginning : Bool = false, ... expr : haxe.macro.Expr) {

	// checking the kind of field, should be a `FFun`
	switch(field.kind) {

		case FFun(f):
			// the existing function expression block.
			var existing = f.expr.expr;

			switch(existing) {
	
				case EBlock(block):
					// we either inject this at the beginning or the end based on the parameter.
					if (atBeginning) { 
						for (i in 0 ... expr.length) block.unshift(expr[expr.length-i-1]);
					} else for (e in expr) block.push(e);

					return;

				default:
					error("attemptint to inject into function @0 but don't know how ...",field.name);
			}

		default:
			error("cannot inject expressions into @0 because it is not a function.", field.name);
	}
}

function registerMap<T>(path : String, interfaceType : Class<T>) : Array<haxe.macro.Expr.Field> {

	var localclass = haxe.macro.Context.getLocalClass().get().name;
	var fields = haxe.macro.Context.getBuildFields();
	var items : Array<haxe.macro.Expr> = [];
	
	// only register if we are not generating documentation
	#if doc_gen

	debug("skipping @0<k,v> registration", localclass);

	#else

	var separator = Consts.COMPONENT_SEPARATOR;

	debug("registering @2<k,v> at path @0 for @1", path, interfaceType, localclass);

	// TODO: update to look inside of build defines and compiler options to know where to look.
	// - possibly remove the paths folder?
	// - take everything inside the project?
	// - get the defined `-cp`
	var src : String = "src";

	for (pp in getPackages(path, src)) {
		var p = pp.p;
		
		// checks if these new class object implement the passed in interface before
		// doing all of this stuff.
		var valid = false;
		for (i in getInterfaces(pp.c))
			if (i == '${interfaceType}') valid = true;
		if (!valid) continue;

		// creates the name so we have it for the map.
		var name = buildName(p, separator, path);

		// PERF: add a check that the class we are loading actually implements the `ecs.Component` interface.

		// sets the new function, so we can make these components
		// FIXME: how can I actually look up how many parameters this interface type needs?
		var expr = if ('$interfaceType' == 'Class<ecs.Component>') macro (e : ecs.Entity) -> new $p(e);
		else macro new $p();
		
		items.push(macro $v{name} => $expr);
	}
	
	for (i in items) {
		debug("@t@0",haxe.macro.ExprTools.toString(i));
	}

	#end

	fields.push({
		name: "all",
		pos: haxe.macro.Context.currentPos(),
		access: [AStatic, APrivate],
		kind: FVar(null, macro $a{items}),
	});

	return fields;

}

/**
 * looks for the supplied class within the source path folders provided and
 * registers them inside of an array. will add everything that implements the
 * supplied interface.
 *
 * @param paths list of source paths to go through.
 * @param interfaceType the class / interface that we are looking for.
 */
function registerArray<T>(paths : Array<String>, interfaceType : Class<T>) : Array<haxe.macro.Expr.Field> {

	var localclass = haxe.macro.Context.getLocalClass().get().name;	
	var fields = haxe.macro.Context.getBuildFields();
	var items : Array<haxe.macro.Expr> = [];

	// only registering items wif we are not generating documentation
	#if doc_gen

	debug("skipping @0[] registration", localclass);

	#else

	var separator = Consts.COMPONENT_SEPARATOR;

	// TODO: update to look inside of build defines and compiler options to know where to look.
	// - possibly remove the paths folder?
	// - take everything inside the project?
	// - get the defined `-cp`
	var src : String = "src";

	debug("registering @2[] at paths @0 for @1", paths, interfaceType, localclass);
	for (path in paths) {

		for (pp in getPackages(path, src)) {
			var p = pp.p;

			// checks if these new class object implement the passed in interface before
			// doing all of this stuff.
			var valid = false;
			for (i in getInterfaces(pp.c)) {
				if (i == '${interfaceType}') valid = true;
			}
			if (!valid) continue;

			var name = "";
			for (i in 1 ... p.pack.length)
				name += p.pack[i] + separator;
			name += p.name;
			/*
			// checking if the final name is the same as the last name in the path, so
			// this allows the same functionality as haxe where you can do component/name/Name.hx and it is
			// available just as component.Name instead of component.name.Name
			if (p.pack.length > 0 && p.pack[p.pack.length-1].toLowerCase() != p.name.toLowerCase()) name += p.name;
			// and if we don't add the final name, then we need to remove the "_" if we
			// placed one earlier (if there was a package path)
			else if (name.charAt(name.length-1) == Consts.COMPONENT_SEPARATOR) name = name.substring(0,name.length-1);
			*/

			// PERF: add a check that the class we are loading actually implements the `ecs.Component` interface.

			// sets the new function, so we can make these components
			// @improvement how can I actually look up how many parameters this
			// interface type needs?
			if ('$interfaceType' == 'Class<ecs.Component>') items.push(macro (e : ecs.Entity) -> new $p(e));
			else items.push(macro new $p());
		}
	}

	for (i in items) {
		debug("@t@0",haxe.macro.ExprTools.toString(i));
	}

	#end

	fields.push({
		name: "all",
		pos: haxe.macro.Context.currentPos(),
		access: [AStatic, APrivate],
		kind: FVar(null, macro $a{items}),
	});

	return fields;
}

/**
 * crawls a folder structure and gets every source file
 * and creates a `PackagePath` expression for it. it doesn't
 * check the contents to ensure that it has the appropriate
 * class or even if that class implements what we are looking for.
 *
 * @improvment make this smarter so that it checks if this is a valid
 * class to add to the path list.
 */
private function getPackages(path : String, src : String) : Array<{ p: haxe.macro.Expr.TypePath, c: haxe.macro.Type.ClassType }> {
	var packages = [];

	var rootPath = haxe.io.Path.join([src,path]);

	if (!sys.FileSystem.exists(rootPath)) {
		trace('path $path does not exist');
		return packages;
	}

	for (f in sys.FileSystem.readDirectory(rootPath)) {
		var fullPath = haxe.io.Path.join([path, f]);
		
		// if this is a directory we go deeper, because we are recursive.
		if (sys.FileSystem.isDirectory(haxe.io.Path.join([src,fullPath]))) {
			for (sp in getPackages(fullPath, src)) packages.push(sp);
		
		// otherwise we check that it is a 'haxe' file, and if it is then
		// we make a `Package Path` item with it.
		} else {
			var ext = haxe.io.Path.extension(f);
			if (ext == "hx") {
				var name = haxe.io.Path.withoutExtension(f);
				var stringname = path.split("/").join(".") + "." + name;
				// loading the file to get all the classes that are inside this file.
				var classes = haxe.macro.Context.getModule(stringname);
				for (c in classes) switch(c) {
					case TInst(t, params):
						var tget = t.get();
						packages.push({
							p: { pack: tget.pack, name: tget.name, },
							c: tget,
						});

					default: // ignore, we don't care.
				}

			}
		}
	}

	return packages;
}

function getInterfaces(c : haxe.macro.Type.ClassType) : Array<String> {
	var interfaces = [ ];

	// gets the standard interfaces.
	for (i in c.interfaces) { 
		interfaces.push('Class<${i.t}>');
		// need to check if that interface extends anything.
		var sinterfaces = getInterfaces(i.t.get());
		for (s in sinterfaces) interfaces.push(s);
	}
	// checks if it extends anything, and if so we go recursively up the chain.
	if (c.superClass != null) {
		var sinterfaces = getInterfaces(c.superClass.t.get());
		for (s in sinterfaces) interfaces.push(s);
	}

	return interfaces;
}

/**
 * specifically gets how many requirements field names for the given function.
 */
function getFieldsFromPath(name : String, functionName : String) : Array<haxe.macro.Expr> {
	var fields = [];

	var ctype = getComplexTypeFromPath(name);
	var type = haxe.macro.ComplexTypeTools.toType(ctype);
	var c = haxe.macro.TypeTools.getClass(type);
	for (f in c.fields.get()) {
		if (f.name.length > functionName.length && f.name.substring(0, functionName.length + 13) == functionName + "_requirements") {

			var arrayitems = switch(f.expr().expr) {
				case TArrayDecl(items): 
					var a = [];
					for (i in items) switch (i.expr) {
						case TConst(TString(text)):
							a.push(macro $v{text});
						default:
							error('this is another issue');
					}
					a;
				default:
					error('this is an issue');
					[];
			}

			fields.push({
				pos: haxe.macro.Context.currentPos(),
				expr: haxe.macro.Expr.ExprDef.EArrayDecl(arrayitems),
			});
		}
	}
	return fields;
}

/**
 * gets the interfaces from a `a.b.c.d` type path name string.
 */
function getInterfacesFromPath(name : String) : Array<haxe.macro.Type.ClassType> {
	var ctype = getComplexTypeFromPath(name);
	var type = haxe.macro.ComplexTypeTools.toType(ctype);
	var c = haxe.macro.TypeTools.getClass(type);
	var interfaces = [ ];
	for (ic in c.interfaces) interfaces.push(ic.t.get());
	return interfaces;
}

function getComplexTypeFromPath(name : String) : haxe.macro.Expr.ComplexType {
	var parts = name.split(".");
	parts[parts.length-1] = parts[parts.length-1].charAt(0).toUpperCase()
		+ parts[parts.length-1].substr(1).toLowerCase();
	var pname = parts.pop();

	var ctype : haxe.macro.Expr.ComplexType = TPath({
		name: pname,
		pack: parts,
	});

	return ctype;
}

function buildName(p : haxe.macro.Expr.TypePath, separator : String, ?srcPath : String) : String {
	var packagePath = p.pack.copy();
	
	// removes the parent directory(s) so its just the
	// root path to the component.
	if (srcPath != null) {
		// TODO: change this to be more neutral, i use "/" because i'm linux but would someone else use "\"?
		var parents = srcPath.split("/");
		for (_ in 0 ... parents.length)
			packagePath.shift();
	}

	var string = packagePath.join(separator);

	// checks if we have a nested package / type so that we don't have a
	// redundent naming convention a/b/c/c for example.
	if (p.pack.length > 0 && p.pack[p.pack.length-1].toLowerCase() != p.name.toLowerCase()) {
		if (string.length > 0) string += separator;
		string += p.name;
	} else if (p.pack.length == 0)
		// in the case that this is a type, it will not have a pack.
		string = p.name;
		
	// makes it all lowercase.
	return string.toLowerCase();
}

/**
 * creates the component string path (what is used in entities) from
 * a ComplexType
 */
function buildComponentName(type : haxe.macro.Expr.ComplexType) : String {

	switch(type) {
		case TPath(path):
			return buildName(path, Consts.COMPONENT_SEPARATOR,"");

		case other: 
			error("cannot build component name from @0",other);
			return "";
	}
}

/**
 * a quick way to check if an array of build fields
 * has a particular field already defined. only checks
 * for the name.
 *
 * @param fields the list of build fields, most likely from `haxe.macro.Context.getBuildFields()`
 * @param name the name of the field to check.
 */
function hasField(fields : Array<haxe.macro.Expr.Field>, name : String) : Bool {
	for (f in fields) if (f.name == name) return true;
	return false;
}

/**
 * returns the field from a list of build fields.
 *
 * @param fields the list of build fields, most likely from `haxe.macro.Context.getBuildFields()`
 * @param name the name of the field to find.
 */
function getField(fields:Array<haxe.macro.Expr.Field>, name : String) : Null<haxe.macro.Expr.Field> {
	for (f in fields) if (f.name == name) return f;
	return null;
}

function getAnonymousFields(type : haxe.macro.Expr.ComplexType) : Null<Array<haxe.macro.Expr.Field>> {
	
	// we need to check if its a typedef, because if so then we might be trying to define
	// requirements for a system that takes different kinds of enemies.
	switch(type) {

		// probably an entity definition, but need to confirm. for that to be the case every
		// field in this structure must be a component.
		case TAnonymous(fields):
			return fields;
		
		case TPath(path):
			var resolved = haxe.macro.Context.resolveType(type, haxe.macro.Context.currentPos());
			
			var tt = switch(resolved) {
				case TType(tt, _): tt.get().type;
				default: return null;
			}

			var fields = switch(tt) {
				case TAnonymous(a): a.get().fields;
				default: return null;
			}

			var processedFields : Array<haxe.macro.Expr.Field> = [];
			for (f in fields) {
				var complexType = haxe.macro.TypeTools.toComplexType(f.type);
				processedFields.push({
					name: f.name,
					kind: FVar(complexType, null),
					pos: haxe.macro.Context.currentPos(),
				});
			}
			return processedFields;
			/*

			switch(resolved) {

				var tt = switch(

				case TType(tt, _): switch(tt.get().type) {
					case TAnonymous(a):
						var fields = a.get().fields;
						for (f in fields) switch(f.type) {
							case TInst(a,b):
							
							default: return null

						}

					default:
						return null;
				}

				default:
					return null;
					}
*/
		default:
			return null;
	}
	return null;
}

			/*

				// could be an entity definition, or could be just a variable that we will pass in.
				case TPath(path):
					var resolved = haxe.macro.Context.resolveType(a.type, haxe.macro.Context.currentPos());
					switch(resolved) {
						case TType(tt, _):
							trace(tt.get().type);
						default:
							// nothing to do here ... not a component.
					}

				default:
					// nothing, just keep looping
			}
		}


	return null;
}

*/

#end
