package ecs;

/**
 * entity management class.
 *
 * a static class that manages all aspects of entities within the **ECS** system.
 */
class Entities {
	/**
	 * a list of all entities that are currently tracked by the ecs.
	 *
	 * should not be used
	 * @see add
	 */
	public static var all : Array<ecs.Entity> = [];

	/**
	 * adds an entity to the global list of tracked entities. is automatically injected into
	 * the new function of the implementation of `ecs.entitiy` so do not use this directly.
	 *
	 * @param e the entitiy to add.
	 */
	public static function add(e : ecs.Entity) {
		all.push(e);
	}
/*
	public static function fromDefinition(file : String) : ecs.Entity {
		var entity = makeEntity();
		entity.id = file + "-" + entity.id;
		debug("making entity @0", entity.id);

		var definition = getFileContents(file);

		var components = Reflect.fields(definition);
		for (d in components) {
			var value = Reflect.getProperty(definition, d);
			entity.addComponent(d, value);
			//ecs.Components.create(entity, d, value);
		}

		for (s in initSystems) {
			ecs.Systems.runOnEntity(s, entity);
		}
		return entity;
	}*/
}
