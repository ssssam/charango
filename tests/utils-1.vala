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

class UtilsTest {

public UtilsTest() {
	// FIXME: vala bug https://bugzilla.gnome.org/show_bug.cgi?id=645178
	Test.add_data_func ("/charango/utils/namespace_uris_match()",
	                    this.test_namespace_uris_match);
}

public void test_namespace_uris_match () {
	assert (namespace_uris_match ("http://example.com", "http://example.com") == true);
	assert (namespace_uris_match ("http://example.com#", "http://example.com") == true);
	assert (namespace_uris_match ("http://example.com/", "http://example.com") == true);
	assert (namespace_uris_match ("http://example.com", "http://example.com#") == true);
	assert (namespace_uris_match ("http://example.com", "http://example.com/") == true);
	assert (namespace_uris_match ("http://example.com/", "http://example.com/") == true);
	assert (namespace_uris_match ("http://example.com#", "http://example.com#") == true);

	assert (namespace_uris_match ("http://example.com/", "http://example.com/a") == false);
	assert (namespace_uris_match ("http://example.com#a", "http://example.com#") == false);
	assert (namespace_uris_match ("http://example.com/", "http://gnome.org/") == false);
}

}

public int main (string[] args) {
	Test.init (ref args);

	new UtilsTest ();
	return Test.run ();
}
