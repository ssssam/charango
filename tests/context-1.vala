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

class ContextTest {

public ContextTest() {
	// FIXME: vala bug https://bugzilla.gnome.org/show_bug.cgi?id=645178
	Test.add_data_func ("/charango/context/local-ontology-sources",
	                    this.test_local_ontology_sources);
	Test.add_data_func ("/charango/context/heirarchy",
	                    this.test_heirarchy);
	Test.add_data_func ("/charango/context/external-references",
	                    this.test_external_references);
	Test.add_data_func ("/charango/context/live",
	                    this.test_live);
}

/* Basic file handling */
public void test_local_ontology_sources () {
	var context = new Charango.Context ();

	// Add non-existent directory
	bool error_was_thrown = false;
	try {
		context.add_local_ontology_source ("/test/nonexistent/directory");
	}
	catch (FileError error) {
		if (error is FileError.NOENT)
			error_was_thrown = true;
	}

	assert (error_was_thrown);
}

void check_heirarchy (Charango.Class c,
                      ... /* List of names children of c */) {
	var va = va_list();

	var children = c.get_children();
	for (uint i=0; i<children.length(); i++) {
		string name = va.arg();

		// Check the class called 'name' appears in list of children of 'c'
		unowned Charango.Class child = null;
		foreach (unowned Charango.Class node in children)
			if (node.name == name) {
				child = node;
				break;
			}
		assert (child != null);

		// Check 'c' is in the child's parent list
		unowned Charango.Class parent = null;
		foreach (unowned Charango.Class node in child.get_parents())
			if (node == c) {
				parent = node;
				break;
			}
		assert (parent != null);
	}
}

/* heirarchy:
 * 
 * Simple test of class inheritance
 */
public void test_heirarchy () {
	var context = new Charango.Context ();
	List<Warning> warning_list;

	try {
		var test_ontology_file = test_ontology_dir + "test-heirarchy.ontology";
		context.load_ontology_file (test_ontology_file);
		context.load (out warning_list);
	}
		catch (FileError e) { error (e.message); }
		catch (ParseError e) { error (e.message); }

	assert (warning_list.length() == 0);

	Charango.Class c;
	c = context.get_class_by_uri_string_noerror ("test_heirarchy:Animal");
	check_heirarchy (c, "Monkey", "Chicken");

	c = context.get_class_by_uri_string_noerror ("test_heirarchy:Food");
	check_heirarchy (c, "Chicken");
}

/* external-references:
 *
 * Predicates about resources in other ontologies that we
 * do not know are permitted, but useless at least for Charango. An example:
 *   http://www.semanticoverflow.com/questions/1653/
 * We must be able to parse them, identify them and ignore them.
 */
public void test_external_references () {
	var context = new Charango.Context ();
	List<Warning> warning_list;

	try {
		var test_ontology_file = test_ontology_dir + "test-external-references.ontology";
		context.load_ontology_file (test_ontology_file);
		context.load (out warning_list);
	}
		catch (FileError e) { error (e.message); }
		catch (ParseError e) { error (e.message); }

	// We should have one warning, about the unavailable external link
	assert (warning_list.length() == 1);
}

/* live:
 * Test the real ontology data parses */
public void test_live () {
	var context = new Charango.Context();

	try {
		context.add_local_ontology_source (SRCDIR + "/charango/data/ontologies");
		context.load (null);
	}
		catch (FileError e) { error (e.message); }
		catch (ParseError e) { error (e.message); }

	context.set_ontology_prefix ("http://purl.org/ontology/mo/", "mo");

	Charango.Class mo_music_artist = context.get_class_by_uri_string_noerror ("mo:MusicArtist");
	assert (mo_music_artist != null);
}

}

public int main (string[] args) {
	Test.init (ref args);

	new ContextTest ();
	return Test.run ();
}
