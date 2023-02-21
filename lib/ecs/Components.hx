package ecs;

/**
 * component management class.
 *
 * a static class that is used to manage all registered components
 */
@:build(ecs.macro.Components.register())
class Components {

	/**
	 * creates a new component for the supplied entity. if the component already exists then it will
	 * not create a new one, but instead set the params (if provided).
	 */
	public static function create(entity : ecs.Entity, name : String, ?params : Dynamic) : ecs.Component {

		#if doc_gen
		// put this in here because i couldn't get it to build without loading systems.
		return null;
		#else

		var newfunc = all.get(name);
		if (newfunc == null) error("component @0 isn't a valid component", name);
		else debug("@tadding component @0 ?@1", name, params);

		// gets a component object.
		var component = {
			// first we check if the entity already has the component
			var existing = entity.getComponent(name);
			if (existing != null) existing;
			// if it doesn't then we have to create a new one and then
			// add it to the entity.
			else {
				var newcomp = newfunc(entity);
				// entity.addComponent(name, newcomp);
				newcomp;
			}
		}

		if (params != null) {
			// works through each supplied parameter and sets it
			// in the new component.
			var fields = Reflect.fields(params);
			for (f in fields) {
				component.load(f, Reflect.getProperty(params, f));
			}
			// runs the reload function
			component.reload();
		}

		return component;
		#end
	}
}
