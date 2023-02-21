package ecs.macro;

#if macro
/**
 * loads all components and saves them in a static private
 * member called `all`
 */
function register() : Array<haxe.macro.Expr.Field> {
	return Utils.registerMap("components", ecs.Component);
}
#end
