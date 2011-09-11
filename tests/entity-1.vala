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

const string ontology_dir = SRCDIR + "/charango/data/ontologies/";
const string test_ontology_dir = SRCDIR + "/charango/tests/data/ontologies/";

class EntityTest: GLib.Object {

public EntityTest() {
	Test.add_data_func ("/charango/entity/primitive types", this.test_primitive_types);
	//Test.add_data_func ("/charango/entity/type checking", this.test_type_checking);
}

public void test_primitive_types () { /* Unit test */
	List<Warning> warning_list = null;
	// Fixture. FIXME: MUST be a better way to do all this
	Charango.Context context = new Charango.Context ();
	Charango.Namespace test_ns;

	try {
		context.add_local_ontology_source (test_ontology_dir);
		context.add_local_ontology_source (ontology_dir);
		context.load_namespace ("http://example.com/test-entity#");
		test_ns = new Charango.Namespace (context, "http://example.com/test-entity#", "test");
	}
	  catch (FileError e) { error (e.message); }
	  catch (RdfError e) { error (e.message); }

	assert (warning_list.length() == 0);

	// The actual test
	var entity = new Charango.Entity (test_ns,
	                                  "http://example.com/test-entity#1",
	                                  context.find_class ("http://example.com/test-entity#BasicEntity"));
	entity.set_predicate ("http://example.com/test-entity#string", "test");
	entity.set_predicate ("http://example.com/test-entity#boolean", true);
	entity.set_predicate ("http://example.com/test-entity#integer", -1);
	entity.set_predicate ("http://example.com/test-entity#double", 0.1);

	var date = Date();
	date.set_dmy (7, DateMonth.APRIL, 2011);
	entity.set_predicate ("http://example.com/test-entity#date", date);

	var datetime = new DateTime.now_local ();
	entity.set_predicate ("http://example.com/test-entity#dateTime", datetime);

	entity.set_predicate ("http://example.com/test-entity#float", (float)1.0);

	assert ((string)entity.get_predicate ("http://example.com/test-entity#string") == "test");
	assert ((bool)entity.get_predicate ("http://example.com/test-entity#boolean") == true);
	assert ((int)entity.get_predicate ("http://example.com/test-entity#integer") == -1);
	assert ((double)entity.get_predicate ("http://example.com/test-entity#double") == 0.1);
	assert (date.compare ((GLib.Date) entity.get_predicate ("http://example.com/test-entity#date")) == 0);
	assert (datetime.compare ((GLib.DateTime) entity.get_predicate ("http://example.com/test-entity#dateTime")) == 0);
	assert ((float)entity.get_predicate ("http://example.com/test-entity#float") == 1.0);
}

static int warning_count;

void warning_counter (string? log_domain,
                      LogLevelFlags log_levels,
                      string message) {
	warning_count ++;
}

#if false

public void test_type_checking() {
	List<Warning> warning_list = null;
	// Fixture. FIXME: MUST be a better way to do all this
	Charango.Context context = new Charango.Context ();
	Charango.Namespace test_ns;

	try {
		context.add_local_ontology_source (test_ontology_dir);
		context.add_local_ontology_source (ontology_dir);
		context.load_namespace ("http://example.com/test-entity#");
		test_ns = new Charango.Namespace (context, "http://example.com/test-entity#", "test");
	}
	  catch (FileError e) { error (e.message); }
	  catch (RdfError e) { error (e.message); }

	assert (warning_list.length() == 0);

	var entity = new Charango.Entity (test_ns,
	                                  "http://example.com/test-entity#1",
	                                  context.find_class ("http://example.com/test-entity#BasicEntity"));

	/* The setter functions warn rather than raising an exception, to avoid
	 * requiring the programmer to put every property access in a try/catch
	 * block when the errors are really programmer errors, not runtime exceptions.
	 */
	/* FIXME: glib-2.0.vapi has wrong prototypes:
	 * https://bugzilla.gnome.org/show_bug.cgi?id=649644 */
	/*var old_fatal_mask = */Log.set_always_fatal (0);
	/*var old_default_handler = */Log.set_default_handler (warning_counter);
	warning_count = 0;

	entity.set_predicate ("integer", "This is not an integer");
	assert (warning_count == 1);

	warning_count = 0;
	entity.get_predicate ("string");
	assert (warning_count == 1);

	/*Log.set_always_fatal (old_fatal_mask);
	Log.set_default_handler (old_default_handler);*/
}

#endif

}



public int main (string[] args) {
	Test.init (ref args);

	new EntityTest ();
	Test.run ();

	return 0;
}
