package ecs.macro;

#if macro

private typedef IFunc = {
	name: String,
	args: Array<Arg>,
};

private typedef Arg = {
	name: String,
	type: haxe.macro.Expr.ComplexType,
};

/**
 * build macro that is used when building a system.
 *
 * this is setup as an `autobuild` on `ecs.System` so
 * nothing is required to be updated / added to the
 * final implementation.
 */
function build() : Array<haxe.macro.Expr.Field> {
	var fields = haxe.macro.Context.getBuildFields();
	var local = haxe.macro.Context.getLocalClass();

	// TODO: there was a comment that this is broken? investigate.
	// => this doesn't actually work, i can only run these function inside of `update(dt)` and nothing else.
	if (local.get().isInterface)
		return buildForInterface(fields);

	else {
		// ensures that the class has a `new` function
		if (!Utils.hasField(fields, "new")) 
			fields.push(Utils.createFunctionField("new"));

		// works through the interface defined functions to update the parameter
		// to match the interface, and setup the variable casts so that the implementor
		// doesn't have to mess around with casting things.
		for (func in getInterfaceFunctions(local.get())) {
			var field = Utils.getField(fields, func.name);

			if (field == null)
				error("@0 does not implement @1", local.get().name, func.name);

			// get the original arguements for the user implemented version of this function
			var ogArgs = getFieldArgs(field);
			// injects the original arguements as cast gets of the new arguements (that we
			// will inject later).
			injectCasts(field, ogArgs);

			// adjust the function args.
			setFunctionArgs(field, func.args);

			// fields.push(createCheckFunction(func.name, ogArgs));

			// creates some variables for us to check for requirements.
			createRequirementFields(func.name, fields, ogArgs);
		}

		fields.push({
			name: "name",
			pos: haxe.macro.Context.currentPos(),
			access: [APublic],
			kind: FVar(macro : String, macro $v{local.get().module}),
		});

	return fields;
	}
}

/**
 * creates a field for every function of the interface that describes what kind of
 * entities are required to run the function
 */
private function createRequirementFields(name : String, fields : Array<haxe.macro.Expr.Field>, args : Array<Arg>) {
	var entities = getEntityRequirements(args);
	for (i in 0 ... entities.length) {
		fields.push({
			name: name + "_requirements_" + i,
			access: [APublic],
			pos: haxe.macro.Context.currentPos(),
			kind: FVar(null, macro $v{entities[i]}),
		});
	}
}

/**
 * ensures that the fields contains a `new` function,
 * if one does not exist it will create a blank empty
 * initalization function that does not have any arguements
 */
/*
private function generateNew(fields : Array<haxe.macro.Expr.Field>) {
	for (f in fields) if (f.name == "new") return;
	fields.push(Utils.createFunctionField("new"));
}
*/

/**
 * extracts the function and arguements from the interface
 * into a format that is easier to parse / work with,
 */
private function getInterfaceFunctions(local : haxe.macro.Type.ClassType) : Array<IFunc> {
	var functions = [];

	// checks each implementing interface for specific
	// functions.
	for (iface in local.interfaces) {
		// goes through the fields in that interface and only
		// processes those that are functions.
		for (field in iface.t.get().fields.get()) switch(field.type) {

			case TFun(arguements, _):

				var args :Array<Arg> = [];

				// loads the arguements into a new structure
				for (a in arguements) args.push({
					name: a.name,
					type: haxe.macro.TypeTools.toComplexType(a.t),
				});

				// saves this function with arguements.
				functions.push({
					name: field.name,
					args: args,
				});

			default: // ignore the rest.
		}
	}

	return functions;
}

/**
 * extracts the arguements for the function
 */
private function getFieldArgs(field : haxe.macro.Expr.Field) : Array<Arg> {
	var args = [];

	switch(field.kind) {
		case FFun(func):
			for (a in func.args) {
				args.push(a);
			}
		case other: error("cannot extract args from type @0", other);
	}

	return args;
}

/**
 * sets the arguements for the field function to the supplied arguments
 */
private function setFunctionArgs(field : haxe.macro.Expr.Field, args : Array<Arg>) {
	switch(field.kind) {
		case FFun(func):
			// drains the current arguements and throws them away.
			while (func.args.length > 0) func.args.pop();

			// adds the new items.
			for (a in args) {
				func.args.push({
					name: a.name,
					type: a.type,
				});
			}

		case other: error("cannot set arguements for a field of type @0", other);
	}
}

/**
 * takes the arguements provided and modifies them
 * to cast expressions of `get` components from the entity
 */
private function injectCasts(field : haxe.macro.Expr.Field, args : Array<Arg>) {

	////////////////////////////////
	// determines how many entities we want and what are their variables
	// for the components.

	var entities = [ ];
	var single = false;
	for (a in args) {

		var af = Utils.getAnonymousFields(a.type);

		// if this has a field and we already said that we should have
		// a single entity, we error.
		if (af != null && single)
			error("cannot make system because mixing anonymous and parameter modes!");

		// TODO: need to put a check to ensure that this is 100% component or 0% component.
		// we found an anonymous function and assume its a component.
		else if (af != null) {
			var ent = {id:a.name, components:[]};
			for (field in af) {
				var complexType = switch(field.kind) {
					case FVar(ct, _): ct;
					// shouldn't do this ever... i think
					default: error("error here?!"); return;
				}

				ent.components.push({
					name: field.name,
					component: Utils.buildComponentName(complexType),
					type: complexType
				});
			}
			entities.push(ent);
			
		// perhaps we are doing a single setup, the original mode.
		} else if (isComponent(a)) {
			single = true;

			if (entities[0] == null) entities.push({id:"",components:[]});

			entities[0].components.push({
				name: a.name,
				component: Utils.buildComponentName(a.type),
				type: a.type,
			});

		}
	}

	///////////////////////////////
	// the injection

	var castExpressions : Array<haxe.macro.Expr> = [];

	if (single) {
		// if we are doing single we just do everything as parameters, no entity group
		
		for (i in 0 ... entities[0].components.length) {
			var idname = entities[0].components[i].name;
			var castexpr : haxe.macro.Expr.ComplexType = entities[0].components[i].type;
			castExpressions.push(
					macro var $idname = cast(entities[0].getComponent($v{entities[0].components[i].component}), $castexpr)
			);
		}

	} else {
		// if we are not 'single' then we have multiple entities, and need to group
		// them in anonymous structures.

		for (i in 0 ... entities.length) {
			var entry : haxe.macro.Expr;
			for (j in 0 ... entities[i].components.length) {
				// had to make these temp vars because using ${entities[i].name} wouldn't compile for me.
				var idname = entities[i].components[j].name;
				var castexpr : haxe.macro.Expr.ComplexType = entities[i].components[j].type;
				var item = macro { $idname:  cast(entities[$v{i}].getComponent($v{entities[i].components[j].component}), $castexpr) };
				if (j == 0) entry = item;
				else {
					var field = switch(item.expr) {
						case EObjectDecl(fields): fields[0];
						default: error("i shoudln't be here!!"); return;
					}
					switch(entry.expr) {
						case EObjectDecl(fields): fields.push(field);
						default: error("i shoudln't be here!!"); return;
					}
				}
			}

			var idname = entities[i].id;
			castExpressions.push(
				macro var $idname = $entry
			);
		}

	}

	Utils.inject(field, true, ... castExpressions);

	/*
	switch(field.kind) {
		case FFun(func):

			var castExpressions = [];
			for (a in args) {	
				// checks if we should cast this.
				if (!isComponent(a)) continue;

				var idname = a.name;
				var stringname = Utils.buildComponentName(a.type);
				// had to manually make the expression because i couldn't figure
				// out how to make this inside the macro down below ...
				var stringnameExpr : haxe.macro.Expr = {
					pos: haxe.macro.Context.currentPos(),
					expr: EConst(CString(stringname, DoubleQuotes)),
				};
				var castexpr : haxe.macro.Expr.ComplexType = a.type;
				// creating the cast expression and adding it to the list of expressions
				castExpressions.push(
					macro var $idname = cast(entities[0].getComponent($e{stringnameExpr}), $castexpr)
				);
			}

			// and now that we have the casts setup, we should inject these to the
			// beginning of the function so that we have the variables
			// available for use.
			switch(func.expr.expr) {
				case EBlock(block):

					for (ce in castExpressions)	block.unshift(ce);

				case other: error("inject casts unimplemented for type @0",other);
			}

		case other: error("cannot inject casts for a field of type @0", other);
	}
	*/
}

private function isComponent(a : Arg) : Bool {

	// gets the type so we can get some smart stuff
	var t = haxe.macro.Context.resolveType(a.type, haxe.macro.Context.currentPos());

	switch(t) {
		// a core type, so no.
		case TAbstract(_, _):
			return false;

		// could be a component, need to check if it implements.
		case TInst(classType, _):
			for (i in Utils.getInterfaces(classType.get()))
				if (i == '${ecs.Component}') return true;
			return false;

		default:
			return false;
	}
}

private function getEntityRequirements(args : Array<Arg>) : Array<Array<String>> {
	var entities = [ ];

	for (a in args) {

		if (!isComponent(a)) {

			var fields = Utils.getAnonymousFields(a.type);
			if (fields != null) {
				//////////////////
				// processes the fields to determine if its an entity.
				var isEntity = true;
				var requirements = [ ];
				
				for (f in fields) {
					switch(f.kind) {
						case FVar(t, _):

							// checks the complextype to see if it implements ecs.component.
							if (!isComponent({name:"", type: t})) isEntity = false;
							else requirements.push(Utils.buildComponentName(t));

						default:
							// can't be a component because not a var.
							isEntity = false;
					}
				}

				/////////////////
				// if it is then we add it to the entitiy list.
				if (isEntity)
					entities.push(requirements);

			}
			
		// if any of these parameters are entities that means
		// we can only have 1 entity.
		} else {
			if (entities[0] == null) entities[0] = [];
			entities[0].push(Utils.buildComponentName(a.type));
		}
	}

	return entities;
}

private function createCheckFunction(name : String, args : Array<Arg>) : haxe.macro.Expr.Field {

	//var checkcomponents = [ ];

	// a list of requirements for each entity.
	var entities = getEntityRequirements(args);

	///////////////////////////////////////////////////////////////
	// makes all the checks.

	var checkSets : Array<haxe.macro.Expr> = [];
	for (i in 0 ... entities.length) {
		var comps = [];
		var entityVar = 'e$i';
		checkSets.push(macro {
			var $entityVar = entities[0];
			for (a in $v{entities[i]})
				if ($i{entityVar}.getComponent(a) == null) 
					return false;
		});
	}
	// adds the last check all, so that we approve the system if it passes
	// all the checks.
	checkSets.push(macro return true);

	/////////////////////////////////////////////////////////////////

	return {
		name: "can" + name,
		access: [APublic],
		pos: haxe.macro.Context.currentPos(),
		kind: FFun({
			args: [{ name: "entities", type : macro : Array<ecs.Entity>, }],
			expr: macro $b{checkSets},
		}),
	}
}

private function makeEField(one : String, two : String) : haxe.macro.Expr {
	return {
		pos: haxe.macro.Context.currentPos(),
		expr: EField({
			pos: haxe.macro.Context.currentPos(),
			expr: EConst(CIdent(one)),
		}, two),
	};
}

// TODO: figure out what I am doing with this...
private function buildExprPath(string : String) : haxe.macro.Expr {
	var split = string.split(".");

	if (split.length < 2) throw 'an error here!';

	var piece = makeEField(split[0], split[1]);

	for (i in 2 ... split.length) {
		piece = {
			pos: haxe.macro.Context.currentPos(),
			expr: EField(piece, "Init"),
		};
	}

	return piece;
}

/**
 * a branch of the `build()` function that that is for interfaces
 * and not the final system.
 */
private function buildForInterface(fields : Array<haxe.macro.Expr.Field>) : Array<haxe.macro.Expr.Field> {

	// the name of the module.
	var moduleName = haxe.macro.Context.getLocalModule();
	
	// gets the static class for the interface.
	var staticClass = {
		var module = haxe.macro.Context.getModule(moduleName);
		var moduleNameParts = moduleName.split(".");
		var staticName = moduleNameParts[moduleNameParts.length-1];
		// var staticPath = moduleNameParts.join(".");
		macro class $staticName { }
	};

	for (field in fields) {

		////////////////////////////////////////////////////////

		// the args lifted from the interface's function
		var existingArgs = [];
		// the name of the arguements in an easy to get array.
		var argsNames : Array<haxe.macro.Expr> = [];

		switch(field.kind) {
			case FFun(f): for (a in f.args) {
				// checking each arguement to see if its a rest arguement with entities.
				// we will strip this from the function because it is not required. (the
				// entire point of this switch).
				switch(a.type) {
					case TPath(path) : if (path.name == "Rest") continue;
					default:
				}

				// now that we know this isn't a rest, lest put this into the function
				existingArgs.push(a);
				argsNames.push(macro $i{a.name});
			}

			default:
				// we don't do anything here since we only care about functions. if its something
				// else thats probably OK.
		}

		///////////////////////////////////////////////////////

		// TODO: find out what this is and document it.
		var path = buildExprPath(moduleName);
		argsNames.unshift(path);

		// we add ??
		staticClass.fields.push({
			name: field.name,
			access: [APublic, AStatic],
			pos: haxe.macro.Context.currentPos(),
			kind: FFun({
				args: existingArgs,
				expr: macro ecs.Systems.run($a{argsNames})
			}),
		});

	}

	return fields;

}

#end
