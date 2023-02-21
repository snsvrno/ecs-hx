package ecs;
/**
 * a **e**ntity in the **ECS** network.
 */
@:autoBuild(ecs.macro.Entity.build())
interface Entity {
	/**
	 * list of all the components that this entity owns
	 */
	private var components : Map<String, ecs.Component>;

	/**
	 * a unique ID for each instance of the entity, is automatically
	 * generated in the `new` function for all implementations of `ecs.entity`.
	 */
	public var id : String;

	/**
	 * adds a component to the entity.
	 */
	public function addComponent(name : String, values : Dynamic) : Void;

	/**
	 * gets a component from the entity.
	 */
	public function getComponent(name : String) : Null<ecs.Component>;
}
