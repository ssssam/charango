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

class ContextTest {
	public ContextTest() {
		/* FIXME: vala bug https://bugzilla.gnome.org/show_bug.cgi?id=645178 */
		Test.add_data_func ("/charango/context/local-ontology-sources",
		                    this.test_local_ontology_sources);
	}

	public void test_local_ontology_sources () {
		var context = new Charango.Context ();

		/* Add non-existent directory */
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
}


public int main (string[] args) {
	Test.init (ref args);

	new ContextTest ();
	return Test.run ();
}