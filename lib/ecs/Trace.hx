package ecs;

inline function error(msg : String, ... arguements : Dynamic) {
	#if logger
	logger.Logger.error(msg, ... arguements);
	throw('');
	#else
	// @todo need to do the arguement substitution.
	throw("Error: " + replacer(msg, ... arguements));
	#end
}

inline function debug(msg : String, ... arguements : Dynamic) {
	#if debug	
		#if logger
		logger.Logger.debug(msg, ... arguements);
		#else
		Sys.println("debug: " + replacer(msg, ... arguements));
		#end
	#end
}

inline function log(msg : String, ... arguements : Dynamic) {
	#if logger
	logger.Logger.log(msg, ... arguements);
	#else
	Sys.println("log: " + replacer(msg, ... arguements));
	#end
}

inline function fulltrace(msg : String, ... arguements : Dynamic) {
	#if ecs_fulltrace
		#if logger
		logger.Logger.debug("(ecs) " + msg, ...arguements);
		#else
		trace(replacer(msg, ... arguements));
		#end
	#end
}

#if !logger
inline function replacer(msg : String, ... arguements : Dynamic) : String {
	var i;
	var args = arguements.toArray();
	while((i = msg.indexOf("@")) >= 0) {
		var index = msg.substr(i+1,i+1);
		msg = msg.substr(0, i) + args[Std.parseInt(index)].toString() + msg.substr(i+2);
	}
	return msg;
}
#end
