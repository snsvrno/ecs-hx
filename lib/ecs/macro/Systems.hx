package ecs.macro;

#if macro

/**
 * usable information for the system, used to generate the switch cases
 * inside of `runfunc`.
 */
private typedef SystemInfo = {
	/*** the name of the system, equivalent to <system>.name */
	name: String,
	/*** what the system is expecting */
	calls: haxe.macro.Expr,
};

/**
 * macro build function finds all the defined systems in the given paths and
 * creates a run function that is used to check and run these systems.
 *
 * is automatically called by a `build` inside of the library so shoudl not be
 * used again / independently
 */
function register() : Array<haxe.macro.Expr.Field> {
	var fields = Utils.registerArray(["systems", "components"], ecs.System);

	// creates the run function.
	{
		var runfunc = createRunFunction(fields);
		fields.push(runfunc);
	}

	return fields;
}

/**
 * goes through the list of loaded systems inside of the field (assuming
 * its an array) and creates a list of information to then act on.
 *
 * @param field should be the `all` field that is an array containing all loaded systems.
 */
private function getSystemInfo(field : haxe.macro.Expr.Field) : Array<SystemInfo> {
	// the resulting generated info.
	var infos : Array<SystemInfo> = [];

	//////////////////////////////////////////////////////
	// get the list of loaded systems from the field.
	var loadedSystems = switch(field.kind) {
		case FVar(_, expr): switch (expr.expr) {
			case EArrayDecl(items):
				// this is the path we want, extracting these items.
				items;

			default:
				// this should never happen since we control all the steps, but need to put something
				// here so i'm aware of when i "fix" something and make this happen.
				error("unsupported field type in @0, fundamental error - unrecoverable (1)","getSystemInfo");
				[]; // error stops the program, but the compile doesn't know that and expects a return.
		}

		default:
			// this should never happen since we control all the steps, but need to put something
			// here so i'm aware of when i "fix" something and make this happen.
			error("unsupported field type in @0, fundamental error - unrecoverable (2)","getSystemInfo");
			[]; // error stops the program, but the compile doesn't know that and expects a return.
	};

	/////////////////////////////////////////////////////////


	// working through each of the loaded systems.
	for (s in loadedSystems) switch(s.expr) {
		case ENew(t, _):

			// builds the system name from the package path
			var name = {
				var array = t.pack.copy();
				array.push(t.name);
				array.join(".");
			};

			// creates the info entry by looking at the interfaces and
			// making the expression that is needed to check and run the
			// system function(s).
			{
				var array = [ ];

				// all interface objects that this system implements / extends, and then
				// we cycle through all fields of those interfaces.
				for (iface in Utils.getInterfacesFromPath(name)) for (ifield in iface.fields.get()) switch (ifield.type) {
					case TFun(args, _):
						var callArguements : Array<haxe.macro.Expr> = [];
						// the arguement index ...
						// TODO : why is this like this, and not an `i` for loop.
						var ai = 0;
						for (a in args) switch(a.t) {
							case TAbstract(att, _):
								// we do not add the rest arguement, because we add the entities later down
								if ('$att' != "haxe.Rest") callArguements.push(macro args[$v{ai++}]);
							default:
								// don't think we will ever be here, but should put a catch and logger
								// just incase.
								error("don't know what to do with arg @0 of type @1 for system @2",a.name, a.t, name);
						}

						var fieldName = ifield.name;
						var systemType = Utils.getComplexTypeFromPath(name);
						// the check function name.
						var functionName = "can" + fieldName;

						var tfields = Utils.getFieldsFromPath(name, fieldName);
						// set up the entities that we will need to pass.
						for (i in 0 ... tfields.length) callArguements.push(macro a[$v{i}]);
						//trace(name + "." + fieldName + "()");
						//for (ca in callArguements) trace("    " + haxe.macro.ExprTools.toString(ca));

						// the case calls to run the function based on what
						// function should be run.
						array.push(macro {
							// we need to create a set of entities to run this function over.
							if (functionName == null || functionName == $v{fieldName}) {
								// initalizes the matched entities
								var matchedEntities :Array<Array<ecs.Entity>> = {
									var requirements : Array<Array<String>> = $a{tfields};
									var array = [];
									while (array.length < requirements.length) array.push([]);
									// TODO: optimize this by saving this everytime we check what entities to use.
									for (e in entities) {
										for (i in 0 ... requirements.length) {
											var passed = true;
											for (r in requirements[i]) {
												if (e.getComponent(r) == null) passed = false;
											}
											if (passed) array[i].push(e);
										}
									}
									// making sure we have an item in each array, otherwise we
									// should not be running this.
									var canrun = true;
									for (a in array) if (a.length == 0) canrun = false;

									if (canrun) array;
									else [ ];
								};

								for (a in Utils.blend(matchedEntities)) {
									#if ecs_fulltrace
									fulltrace(" - " + a);
									#end

									cast(system, $systemType).$fieldName($a{callArguements});
								}
							}
							
							//if (functionName == null || functionName == $v{fieldName}) {
							//	if (!cast(system, $systemType).$functionName(entities)) return;
							//	cast(system, $systemType).$fieldName($a{callArguements});
							//}
						});

					default:
						// the field is not a function, we don't care about anything but functions
						// so we ignore this, and we don't error because perhaps there is something else
						// that this must implement, that isn't a function
				}

				infos.push({
					name: name,
					calls : macro $b{array},
				});
			}

		default:
			// this should never happen since we control all the steps, but need to put something
			// here so i'm aware of when i "fix" something and make this happen.
			error("unsupported field type in @0, fundamental error - unrecoverable (3)","getSystemInfo");
			[]; // error stops the program, but the compile doesn't know that and expects a return.
	}

	return infos;
}


/**
 * creates a new field that is a function called `runfunc` which is
 * a massive `switch` block that is used to check what system to run.
 *
 * @param fields the build fields for the class.
 */
private function createRunFunction(fields : Array<haxe.macro.Expr.Field>) : haxe.macro.Expr.Field {

	// the soon to be build cases for the switch.
	var cases : Array<haxe.macro.Expr.Case> = [];

	// gets all the loaded systems and builds a case for each of them
	{
		// the loaded systems, stored inside the "all" parameter as an array.
		var loadedSystems = Utils.getField(fields, "all");

		// gets information about the system, used to generate the case.
		var systeminfo = getSystemInfo(loadedSystems);

		// works through each system collected, and generates the case.
		// @see getSystemInfo for more information on what this entails.
		for (sys in systeminfo) cases.push({
			values: [macro $v{sys.name}],
			expr: sys.calls,
		});
	}

	var switchExpression : haxe.macro.Expr = {
		expr: ESwitch(macro system.name, cases, macro trace("cannot find " + system.name)),
		pos: haxe.macro.Context.currentPos(),
	};

	return {
		name: "runfunc",
		access: [APrivate, AStatic],
		pos: haxe.macro.Context.currentPos(),
		kind: FFun({
			args:[
				{ name : "system", type: macro : ecs.System, },
				{ name : "functionName", type: macro : Null<String>, },
				{ name : "entities", type: macro : Array<ecs.Entity>, },
				{ name : "args", type: macro : Array<Dynamic>, },
			],
			expr: macro $b{[
				#if ecs_fulltrace
				macro fulltrace("runfunc(@0,@1,@2,@3)",system, functionName, "..." , args),
				#end
				switchExpression,
			]},
		}),
	}
}

#end
