package ecs;

/**
 * a **s**ystem in the **ECS** network.
 */
@:autoBuild(ecs.macro.System.build())
interface System {
	/**
	 * the name of the system, generated by the build macro
	 */
	public var name : String;
}
