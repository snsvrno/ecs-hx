package ecs;

/**
 * system management class.
 */
@:build(ecs.macro.Systems.register())
class Systems {
	/**
	 * runs the current system for all entities that match the system requirements.
	 * will automatically find the function to run based on the `system`
	 *
	 * @param system the interface (class) of the system to run
	 * @param args the required arguements for that system, this will be different based on the implemention of the system
	 */
	public static function run<T>(system : Class<T>, ... args : Dynamic) {
		for (a in all) if (Std.isOfType(a, system)) {
			runfunc(a, null, ecs.Entities.all, args);
		}
	}

	/**
	 * runs a particual function inside of a system for all entities. this should be usd in the event that a system
	 * has multiple functions, for example if a system was for mouse input, and there was a `pressed`
	 * and `released` function.
	 *
	 * @param system the interface (class) of the system to run
	 * @param name the name of the function to run
	 * @param args the required arguements for that system, this will be different based on the implemention of the system
	 */
	public static function runFunc<T>(system : Class<T>, name : String, ... args : Dynamic) {
		for (a in all) if (Std.isOfType(a, system)) {
			// PERF: runtime check, to make sure that we don't accidently pass something that doesn't exist.
			// placed itin debug because probably don't need this check in release? since if the debug
			// works the release should work too??
			#if debug
			var func = Reflect.getProperty(a, name);
			if (func == null) error("system type @0 does not have a function named @1", '$system', name);
			#end
			runfunc(a, name, ecs.Entities.all, args);
		}
	}

	/**
	 * runs a system but will only attempt to run it on the given entity. will check if the
	 * system is compatible with the entity before running so there should be no errors / issues.
	 *
	 * @param system the interface (class) of the system to run
	 * @param entity the entity to attempt to run the system on.
	 * @param args the required arguements for that system, this will be different based on the implemention of the system
	 */

	public static function runOnEntity<T>(system : Class<T>, entity : ecs.Entity, ... args : Dynamic) {
		for (a in all) if (Std.isOfType(a, system)) runfunc(a, null, [entity], args.toArray());
	}
}
