package ecs.macro;

#if macro

/**
 * build macro that is used when building an entity.
 *
 * this is setup as an `autobuild` on `ecs.Entity` so
 * nothing is required to be updated / added to the
 * final implementation.
 */
function build() : Array<haxe.macro.Expr.Field> {
	var fields = haxe.macro.Context.getBuildFields();
	var localclass = haxe.macro.Context.getLocalClass().get().name;

	//////////////////////////////////////////////////////
	// creates the `components` value that is required by
	// @see ecs.entity
	{
		// checking that the implementation doesn't already contain the field, we can't do anything
		// if it does so we need to error and tell the user that we can't build anymore because
		// of this issue.
		if (Utils.hasField(fields, "components")) 
			error("@0 already implements a field called @1. class must not have a field with this name", localclass, "components");

		fields.push({
			name: "components",
			access: [APrivate],
			pos: haxe.macro.Context.currentPos(),
			kind: FVar(macro : Map<String, ecs.Component>, macro $a{[]}),
		});
	}

		// HACK: need to check if a 'toString' exists, and then do nothing, and if the super (if exists)
		// has a toString, and then add the override.
		fields.push({
			name: "toString",
			access: [APublic, AOverride],
			pos: haxe.macro.Context.currentPos(),
			kind: FFun({
				args: [],
				expr: macro {
					/*
					// a version of the string that shows what keyswe have.
					var string = '<$id';
					for (k =>v in components) {
						string += ' $k,';
					}
					string += ">";
					return string;*/
					return id;
				}
			}),
		});

	////////////////////////////////////////////////////////////////
	// ensuring that the required `new` function hooks are in place.
	{
		// checks if the final implementation already has a new function.
		// if it does not then it will do about trying to grab it so we
		// can inject what we need into it.
		var newfunc = Utils.getField(fields, "new");
		if (newfunc == null) {
			newfunc = Utils.createFunctionField("new");
			fields.push(newfunc);
		}

		// adds a code block at the end of the `new` function, specifically to
		// add this entity to the list of all entites, and to give it a unique ID.
		Utils.inject(newfunc, macro {
			id = ecs.Utils.hash();
			ecs.Trace.fulltrace("creating new entity: @0", id);

			ecs.Entities.add(this);
			ecs.Trace.fulltrace("added @0 to ecs.Entities.all", id);
		});
	}

	////////////////////////////////////////////////////////////
	// implementing the `addComponent` function that is required
	// by @see ecs.entity
	{
		if (Utils.hasField(fields, "addComponent")) 
			error("@0 already implements a field called @1. class must not have a field with this name", localclass, "addComponent");

		fields.push({
			name: "addComponent",
			pos: haxe.macro.Context.currentPos(),
			access: [APublic],
			kind: FFun({
				args: [
					{ name: "componentName", type: macro : String, },
					{ name: "values", type: macro : Dynamic, },
				],
				expr: macro {
////////////////////////////////////////////////////////////////////////////////////////////
					ecs.Trace.fulltrace("adding component @0 to entity @1", componentName, this.id);

					// gets the component.
					var component = ecs.Components.create(this, componentName, values);
					// sets the component in its 'real' name.
					components.set(componentName, component);

					// checks if this component extends anything, and then sets its as the
					// value for those too for easy access in the future.
					for (ec in component.extendsComponents()) {
						var existingcomp = components.get(ec);
						if (existingcomp != null && existingcomp != component) {
							ecs.Trace.error("cannot add @0 because it implements @1 which is already added.",componentName, ec);
						}
						components.set(ec, component);
					}


					var fields = Reflect.fields(values);
					// applies all the values, making sure they are compatible types and exist.
					for (vk in fields) {
						var existing = Reflect.getProperty(component, vk);
						if (existing == null) ecs.Trace.error("component @0 does not have the property @1", componentName, vk);
						component.load(vk, Reflect.getProperty(values, vk));
					}

					component.reload();
					
/////////////////////////////////////////////////////////////////////////////////////////////
				},
			}),
		});
	}

	////////////////////////////////////////////////////////////
	// implementing the `id` propertyr equired by
	// @see ecs.entity
	{
		if (Utils.hasField(fields, "id")) 
			error("@0 already implements a field called @1. class must not have a field with this name", localclass, "id");

		fields.push({
			name: "id",
			pos: haxe.macro.Context.currentPos(),
			access: [APublic],
			kind: FVar( macro : String, null),
		});
	}

	////////////////////////////////////////////////////////////
	// implementing the `getComponent` function that is required
	// by @see ecs.entity
	{
	
		if (Utils.hasField(fields, "getComponents")) 
			error("@0 already implements a field called @1. class must not have a field with this name", localclass, "getComponents");

		fields.push({
			name: "getComponent",
			pos: haxe.macro.Context.currentPos(),
			access: [APublic],
			kind: FFun({
				args: [{ name: "componentName", type: macro : String }],
				expr: macro {
					// the basic one, we have something exactly named what we
					// are looking for.
					return components.get(componentName);
				},
			}),
		});
	}

	return fields;
}

#end
