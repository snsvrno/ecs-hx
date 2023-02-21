package ecs;

/**
 * a **c**omponent in the **ECS** network.
 *
 * the component contains the data that the systems will act on.
 */
@:autoBuild(ecs.macro.Component.build())
interface Component {

	@:dox(hide)
	public function load(key : String, value : Dynamic) : Void;

	@:dox(hide)
	public function reload() : Void;

	@:dox(hide)
	public function extendsComponents() : Array<String>;
}
