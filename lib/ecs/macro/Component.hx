package ecs.macro;

#if macro
/**
 * build macro that is used when building a component.
 *
 * this is setup as an `autobuild` on `ecs.Component` so
 * nothing is required to be updated / added to the
 * final implementation.
 */

function build() : Array<haxe.macro.Expr.Field> {
	var fields = haxe.macro.Context.getBuildFields();
	var localclass = haxe.macro.Context.getLocalClass();

	// don't do anything if this is an interface
	if (localclass.get().isInterface) return fields;

	generateNew(fields);
	/*
	///////////////////////////////////////
	// creates the new function
	{
		// checks if a new function was already created.
		var newfunc = Utils.getField(fields, "new");
		if (newfunc == null) {
			newfunc = Utils.createFunctionField("new");
			fields.push(newfunc);
		}

		// adds a code block at the end of the `new` function, specifically to
		// add this entity to the list of all entites, and to give it a unique ID.
		Utils.inject(newfunc, macro {
			ecs.Entities.add(this);
			id = ecs.Utils.hash();
		});
	}
	*/
	
	generateReload(fields);
	generateLoad(fields);

	setExtends(fields);

	return fields;
}

// @improvement make this support extending multiple components..
private function setExtends(fields : Array<haxe.macro.Expr.Field>) {
	var access : Array<haxe.macro.Expr.Access> = [APublic];

	var items : Array<String> = [];
	var superclass = haxe.macro.Context.getLocalClass().get().superClass;
	if (superclass != null) {
		var pack = {
			name: superclass.t.get().name,
			pack: superclass.t.get().pack,
		};
		// HACK: hard coded that all components are inside the /components folder.
		var name = Utils.buildName(pack, Consts.COMPONENT_SEPARATOR, "components");
		items.push(name);
		access.push(AOverride);
		/*var componentstring = '${superclass.t}'.split(".");
		if (componentstring[0] == "components") {
			componentstring.shift();
			for (i in 0 ... componentstring.length)
				componentstring[i] = componentstring[i].toLowerCase();

			items.push(componentstring.join(Consts.COMPONENT_SEPARATOR));
		}*/

	}

	fields.push({
		name: "extendsComponents",
		access : access,
		pos: haxe.macro.Context.currentPos(),
		kind: FFun({
			args: [],
			expr: macro {
				return $v{items};
			},
		}),
	});
}

function generateNew(fields : Array<haxe.macro.Expr.Field>) {

	var inits : Array<haxe.macro.Expr> = [];

	// finding the init functions and adding them
	// to the list of inits to use. will verify that they are 
	for (f in fields) if (f.name.substring(0,5) == "init_") {
		// adds the init function to the list of injections
		// to make to the new function.
		var name = f.name.substring(5);
		inits.push({
			pos: haxe.macro.Context.currentPos(),
			expr: ECall({
				pos : haxe.macro.Context.currentPos(),
				expr: EConst(CIdent(f.name)),
				// 'e' (below) in this context is the 1st parameter (entity)
				// of the `new component` function. 
				// @todo need to make this actually inject it into the new function
				// because currently NEW doesn't have any arguements.
			}, [ macro e ]),
		});

		// checks that this function is `inline`
		if (!f.access.contains(AInline)) f.access.push(AInline);

		// check that it has either no args (then adds entity) or just entity)
		switch(f.kind) {
			case FFun(f):
				if (f.args.length == 0) f.args.push({ name: "e", type: macro : ecs.Entity, })	
				else if (f.args.length > 1) {
					log("component constructor for @0 must only have 1 arguement, an entity", haxe.macro.Context.getLocalClass().get().name);
				}
			default:
		}
	}

	// adds the reload into the init / so its the last thing we do.
	// inits.push(macro {reload();});

	// @improvement add better error handling that explains that
	// you need a signature of (e : ecs.Entity) -> Void 

	// gets a empty new function.
	var newfun : Null<haxe.macro.Expr.Field> = null;
	for (f in fields) if (f.name == "new") newfun = f;
	if (newfun == null) {
		newfun = Utils.createFunctionField("new");
		fields.push(newfun);
	}

	Utils.inject(newfun, ... inits);
	Utils.setArgs(newfun, { name: "e", type: macro : ecs.Entity, });

	// check if we need to inject a super command, if we are extending anything.
	var local = haxe.macro.Context.getLocalClass();
	if (local.get().superClass != null) {
		Utils.inject(newfun, true, macro { super(e); });
	}
}

/**
 * generates load functions that are used to parse data
 * into different objects
 */
private function generateLoad(fields : Array<haxe.macro.Expr.Field>) {

	// gets the items that already exist.
	var loads : Array<String> = [];
	for (f in fields) if (f.name.substring(0,5) == "load_") loads.push(f.name);
	
	var cases : Array<haxe.macro.Expr.Case> = [];
	for (f in fields) if (f.kind.match(FVar(_))) {
		if (loads.contains("load_" + f.name)) {
			cases.push({
				values: [macro $v{f.name}],
				expr: macro $b{[
					macro $i{"load_" + f.name}(v),
				]},
			});
		} else cases.push({
			values: [ macro $v{f.name} ],
			expr: macro $i{f.name} = v,
		});
	}

	// makes the standard loader function
	var loadfun : haxe.macro.Expr.Field = {
		name: "load",
		access: [APublic],
		pos: haxe.macro.Context.currentPos(),
		kind: haxe.macro.Expr.FieldType.FFun({
			args: [
				{ name: "k", type: macro : String  },
				{ name: "v", type: macro : Dynamic },
			],
			expr: { 
				pos: haxe.macro.Context.currentPos(),
				expr: EBlock([{
						pos: haxe.macro.Context.currentPos(),
						// @improvement originally had a throw that would catch
						// if it was trying to set something it didn't know how to set
						// but i had to remove that because it of inheritence, since
						// it could be trying to set something in the parent or this.
						//
						// one way to fix this would be to put the super in the "default"
						// so that it "super" has the throw and the implemented class
						// doesn't
						expr: ESwitch(macro k, cases, null),
					},
					macro { reload(); },
				]),
			},
		}),
	};

	// check if we need to inject a super command, if we are extending anything.
	var local = haxe.macro.Context.getLocalClass();
	if (local.get().superClass != null) {
		loadfun.access.push(AOverride);
		Utils.inject(loadfun, true, ... [macro super.load(k,v)]);
	}

	fields.push(loadfun);
}

private function generateReload(fields : Array<haxe.macro.Expr.Field>) {

	var reloads : Array<haxe.macro.Expr> = [];
	
	// finding the init functions and adding them
	// to the list of inits to use. will verify that they are 
	for (f in fields) if (f.name.substring(0,7) == "reload_") {
		// adds the init function to the list of injections
		// to make to the new function.
		var name = f.name.substring(5);
		reloads.push({
			pos: haxe.macro.Context.currentPos(),
			expr: ECall({
				pos : haxe.macro.Context.currentPos(),
				expr: EConst(CIdent(f.name)),
			}, [ ]),
		});

		// checks that this function is `inline`
		if (!f.access.contains(AInline)) f.access.push(AInline);
	}

	// @improvement add better error handling that explains that
	// you need a signature of (e : ecs.Entity) -> Void 

	// gets a empty new function.
	var newfun : Null<haxe.macro.Expr.Field> = null;
	for (f in fields) if (f.name == "reload") {
		newfun = f;
		fields.remove(f);
	}
	if (newfun == null) newfun = {
		name: "reload",
		access: [APublic],
		pos: haxe.macro.Context.currentPos(),
		kind: haxe.macro.Expr.FieldType.FFun({
			args: [ ],
			expr: macro $b{[]},
		}),
	};

	Utils.inject(newfun, ... reloads);

	// check if we need to inject a super command and make this an overrload.
	// because we are extending an existing component.
	var local = haxe.macro.Context.getLocalClass();
	if (local.get().superClass != null) {
		newfun.access.push(AOverride);
		// Utils.inject(newfun, true, ... [macro super.reload()]);
	}

	// adds the new field back.
	fields.push(newfun);


}

#end
