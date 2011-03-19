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

class EntityTest {
	public EntityTest() {
		Test.add_data_func ("/test/basic", this.test_basic);
	}

	public void test_basic () {
		/*var entity = new Charango.Entity("mo:MusicArtist");
		entity.set ("rdf:about",
		            "http://musicbrainz.org/artist/ac241ded-3430-4f42-8451-f78667cc2f52");
		entity.set ("foaf:name", "The Aggrolites");
		entity.set ("ov:sortName", "Aggrolites, The");*/
	}
}


public int main (string[] args) {
	Test.init (ref args);

	new EntityTest ();
	Test.run ();

	return 0;
}