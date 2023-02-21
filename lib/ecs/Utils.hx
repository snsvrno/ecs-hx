package ecs;

private inline var hashList = "qazwsxedcrfvtgbyhnujmikolpQAZWSXEDCRFVTGBYHNUJMIKOLP1234567890";

/**
 * creates a randomized string of characters
 */
function hash(?length : Int = 8) : String {
	var string = "";
	
	while(string.length < length) {
		var i = Math.floor(Math.random() * hashList.length);
		string += hashList.charAt(i);
	}

	return string;
}

function blend<T>(array : Array<Array<T>>) : Array<Array<T>> {
	if (array.length == 0) return [];
	else if (array.length == 1) return array;
	else if (array.length == 2) {
		var mixed = [];
		// if its two
		for (a in array[0]) {
			for (b in array[1]) {
				if (a != b) mixed.push([a, b]);
			}
		}
		return mixed;
	}
	else {
		error('this is not implemented for more than 2!');
		return [];
	}
}
