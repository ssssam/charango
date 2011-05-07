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

Charango.Context context;

public EntityTest() {
	Test.add_data_func ("/charango/entity/primitive types", this.test_primitive_types);
}

public void test_primitive_types () {
	List<Warning> warning_list;
	// Fixture. FIXME: MUST be a better way to do all this
	context = new Charango.Context ();

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

}


public int main (string[] args) {
	Test.init (ref args);

	new EntityTest ();
	Test.run ();

	return 0;
}