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

using Charango;

extern static const string SRCDIR;

const string test_ontology_dir = SRCDIR + "/charango/tests/data/ontologies/";

class EntityTest: GLib.Object {

public EntityTest() {
	Test.add_data_func ("/charango/entity/primitive types", this.test_primitive_types);
	Test.add_data_func ("/charango/entity/type checking", this.test_type_checking);
}

public void test_primitive_types () { /* Unit test */
	List<Warning> warning_list;
	// Fixture. FIXME: MUST be a better way to do all this
	var context = new Charango.Context ();

	try {
		var test_ontology_file = test_ontology_dir + "test-entity.ontology";
		context.load_ontology_file (test_ontology_file);
		context.load (out warning_list);
	}
		catch (FileError e) { error (e.message); }
		catch (ParseError e) { error (e.message); }

	assert (warning_list.length() == 0);

	// The actual test
	var entity = new Charango.Entity(context, "test_entity:BasicEntity");
	entity.set_string ("string", "test");
	entity.set_boolean ("boolean", true);
	entity.set_integer ("integer", -1);
	entity.set_double ("double", 0.1);

	var date = Date();
	date.set_dmy (7, DateMonth.APRIL, 2011);
	entity.set_date ("date", date);

	var datetime = new DateTime.now_local ();
	entity.set_datetime ("dateTime", datetime);

	entity.set_float ("float", (float)1.0);

	assert (entity.get_string ("string") == "test");
	assert (entity.get_boolean ("boolean") == true);
	assert (entity.get_integer ("integer") == -1);
	assert (entity.get_double ("double") == 0.1);
	assert (date.compare (entity.get_date ("date")) == 0);
	assert (datetime.compare (entity.get_datetime ("dateTime")) == 0);
	assert (entity.get_float ("float") == 1.0);
}

static int warning_count;

void warning_counter (string? log_domain,
                      LogLevelFlags log_levels,
                      string message) {
	warning_count ++;
}

public void test_type_checking() {
	List<Warning> warning_list;
	// Fixture. FIXME: MUST be a better way to do all this
	var context = new Charango.Context ();

	try {
		var test_ontology_file = test_ontology_dir + "test-entity.ontology";
		context.load_ontology_file (test_ontology_file);
		context.load (out warning_list);
	}
		catch (FileError e) { error (e.message); }
		catch (ParseError e) { error (e.message); }

	assert (warning_list.length() == 0);

	var entity = new Charango.Entity(context, "test_entity:BasicEntity");

	/* The setter functions warn rather than raising an exception, to avoid
	 * requiring the programmer to put every property access in a try/catch
	 * block when the errors are really programmer errors, not runtime exceptions.
	 */
	/* FIXME: glib-2.0.vapi has wrong prototypes:
	 * https://bugzilla.gnome.org/show_bug.cgi?id=649644 */
	/*var old_fatal_mask = */Log.set_always_fatal (0);
	/*var old_default_handler = */Log.set_default_handler (warning_counter);
	warning_count = 0;

	entity.set_string ("integer", "This is not an integer");
	assert (warning_count == 1);

	warning_count = 0;
	entity.get_integer ("string");
	assert (warning_count == 1);

	/*Log.set_always_fatal (old_fatal_mask);
	Log.set_default_handler (old_default_handler);*/
}

}


public int main (string[] args) {
	Test.init (ref args);

	new EntityTest ();
	Test.run ();

	return 0;
}