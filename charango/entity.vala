/*  Charango
 *  Copyright 2011 Sam Thursfield <ssssam@gmail.com>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Charango {

/**
 * Charango.Entity: a data 'object'
 * 
 * More precisely, a #Charango.Entity is an instance of an rdfs:Class.
 */
public class Entity: GLib.Object {

/* FIXME: would be nicer if we could store the values directly in the array,
 * but that requires wrapping GArray in Vala which might be hard ..
 */
Charango.Class rdfs_class;
GenericArray<Charango.Value?> data;

/* In old Entry, we used to index properties with an int. Is that practical here?
 * IF entries were only one class we could use a sort of hashmap and speed things
 * up with that .. we certainly don't want a hash table lookup on every god damn
 * line of every view refresh ...
 */
/* The problem then is that there can be more than one class. While ontologies are
 * fixed, we can use the class heirarchy to find all possible predicates and index
 * them BY class. If we change the heirarchy at run time, no matter because this is
 * all just shortcuts anyway. Restart. The problem is when we can have an Entity
 * which is an instance of more than one class heirarchy.
 *
 * I'm leaning towards just not allowing this.
 */

public Entity (Context  context,
               string   class_uri_string) {
	try {
		rdfs_class = context.get_class_by_uri_string (class_uri_string);
	}
		catch (ParseError e) {
			warning ("%s", e.message);
			return;
		}

	this.data = new GenericArray<Charango.Value?>();
}

public Charango.Class get_rdfs_class () {
	return rdfs_class;
}

/* FIXME: this is a horribly bloated amount of code. If only Vala had a macro
 * language ... well, one day when you have lots of time, go on the Vala list
 * and see if anyone has any ideas for good ways to reduce the amount of code
 * here. Generics or some such.
 */

/* These functions warn on errors instead of throwing exceptions because the
 * possible errors are ontology errors and the ontology is part of the
 * application API. Exceptions are used elsewhere for convenience.
 */

int check_type_and_get_index_for_property (string                 predicate,
                                           Charango.ValueBaseType type)
           throws OntologyError {
	int index = 0;
	Charango.Property property = this.rdfs_class.get_rdfs_property (predicate, &index);

	if (property.type != type)
		throw new OntologyError.TYPE_MISMATCH
		  ("Type mismatch: property '%s' expects %s but got %s",
		   predicate,
		   value_base_type_name[property.type],
		   value_base_type_name[type]);

	return index;
}

public void set_string (string predicate,
                        string object) {
	try {
		int index = check_type_and_get_index_for_property(predicate, ValueBaseType.STRING);
		set_string_by_index (index, object);
	}
	catch (OntologyError e) {
		warning ("%s", e.message);
	}
}

public void set_boolean (string predicate,
                         bool  object) {
	try {
		int index = check_type_and_get_index_for_property(predicate, ValueBaseType.BOOLEAN);
		set_boolean_by_index (index, object);
	}
	catch (OntologyError e) {
		warning ("%s", e.message);
	}
}

public void set_integer (string predicate,
                         int64  object) {
	try {
		int index = check_type_and_get_index_for_property(predicate, ValueBaseType.INT64);
		set_integer_by_index (index, object);
	}
	catch (OntologyError e) {
		warning ("%s", e.message);
	}
}

public void set_double (string predicate,
                        double object) {
	try {
		int index = check_type_and_get_index_for_property(predicate, ValueBaseType.DOUBLE);
		set_double_by_index (index, object);
	}
	catch (OntologyError e) {
		warning ("%s", e.message);
	}
}

public void set_date (string predicate,
                      Date   object) {
	try {
		int index = check_type_and_get_index_for_property(predicate, ValueBaseType.DATE);
		set_date_by_index (index, object);
	}
	catch (OntologyError e) {
		warning ("%s", e.message);
	}
}

public void set_datetime (string   predicate,
                          DateTime object) {
	try {
		int index = check_type_and_get_index_for_property(predicate, ValueBaseType.DATETIME);
		set_datetime_by_index (index, object);
	}
	catch (OntologyError e) {
		warning ("%s", e.message);
	}
}

public void set_float (string predicate,
                       float object) {
	try {
		int index = check_type_and_get_index_for_property(predicate, ValueBaseType.FLOAT);
		set_float_by_index (index, object);
	}
	catch (OntologyError e) {
		warning ("%s", e.message);
	}
}

/* Fast variants: no type or bounds checking is done */

public void set_string_by_index (uint   predicate_index,
                                 string object_literal) {
	if (data.length <= predicate_index)
		data.length = (int)(predicate_index + 1);

	data[predicate_index] = Value.from_string (object_literal);
}

public void set_boolean_by_index (uint predicate_index,
                                  bool object_literal) {
	if (data.length <= predicate_index)
		data.length = (int)(predicate_index + 1);

	data[predicate_index] = Value.from_boolean (object_literal);
}

public void set_integer_by_index (uint  predicate_index,
                                  int64 object_literal) {
	if (data.length <= predicate_index)
		data.length = (int)(predicate_index + 1);

	data[predicate_index] = Value.from_int64 (object_literal);
}

public void set_double_by_index (uint   predicate_index,
                                 double object_literal) {
	if (data.length <= predicate_index)
		data.length = (int)(predicate_index + 1);

	data[predicate_index] = Value.from_double (object_literal);
}

public void set_date_by_index (uint predicate_index,
                               Date object_literal) {
	if (data.length <= predicate_index)
		data.length = (int)(predicate_index + 1);

	data[predicate_index] = Value.from_date (object_literal);
}

public void set_datetime_by_index (uint     predicate_index,
                                   DateTime object_literal) {
	if (data.length <= predicate_index)
		data.length = (int)(predicate_index + 1);

	data[predicate_index] = Value.from_datetime (object_literal);
}

public void set_float_by_index (uint  predicate_index,
                                float object_literal) {
	if (data.length <= predicate_index)
		data.length = (int)(predicate_index + 1);

	data[predicate_index] = Value.from_float (object_literal);
}


public unowned string? get_string (string predicate) {
	try {
		int index = check_type_and_get_index_for_property(predicate, ValueBaseType.STRING);
		return get_string_by_index (index);
	}
	catch (OntologyError e) {
		warning ("%s", e.message);
		return null;
	}
}

public unowned bool get_boolean (string predicate) {
	try {
		int index = check_type_and_get_index_for_property(predicate, ValueBaseType.BOOLEAN);
		return get_boolean_by_index (index);
	}
	catch (OntologyError e) {
		warning ("%s", e.message);
		return false;
	}
}

public unowned int64 get_integer (string predicate) {
	try {
		int index = check_type_and_get_index_for_property(predicate, ValueBaseType.INT64);
		return get_integer_by_index (index);
	}
	catch (OntologyError e) {
		warning ("%s", e.message);
		return 0;
	}
}

public unowned double get_double (string predicate) {
	try {
		int index = check_type_and_get_index_for_property(predicate, ValueBaseType.DOUBLE);
		return get_double_by_index (index);
	}
	catch (OntologyError e) {
		warning ("%s", e.message);
		return 0.0;
	}
}

/* Practically this cannot be null, but vala bug prevents specifying that */
public unowned Date? get_date (string predicate) {
	try {
		int index = check_type_and_get_index_for_property(predicate, ValueBaseType.DATE);
		return get_date_by_index (index);
	}
	catch (OntologyError e) {
		warning ("%s", e.message);
		return null;
	}
}

public unowned DateTime? get_datetime (string predicate) {
	try {
		int index = check_type_and_get_index_for_property(predicate, ValueBaseType.DATETIME);
		return get_datetime_by_index (index);
	}
	catch (OntologyError e) {
		warning ("%s", e.message);
		return null;
	}
}

public unowned float get_float (string predicate) {
	try {
		int index = check_type_and_get_index_for_property(predicate, ValueBaseType.FLOAT);
		return get_float_by_index (index);
	}
	catch (OntologyError e) {
		warning ("%s", e.message);
		return (float)0.0;
	}
}

public unowned string get_string_by_index (uint predicate_index) {
	return data[predicate_index].get_string ();
}

public unowned bool get_boolean_by_index (uint predicate_index) {
	return data[predicate_index].get_boolean ();
}

public unowned int64 get_integer_by_index (uint predicate_index) {
	return data[predicate_index].get_int64 ();
}

public unowned double get_double_by_index (uint predicate_index) {
	return data[predicate_index].get_double ();
}

public unowned Date? get_date_by_index (uint predicate_index) {
	return data[predicate_index].get_date ();
}

public unowned DateTime get_datetime_by_index (uint predicate_index) {
	return data[predicate_index].get_datetime ();
}

public unowned float get_float_by_index (uint predicate_index) {
	return data[predicate_index].get_float ();
}

public void dump () {
}

}

}
