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

public int main (string[] args) {
	var context = new Charango.Context ();
	/* FIXME: make relocatable */
	/* FIXME: or, use tracker ones! We don't need to query them via sparql at all!!! */
	var path = Path.build_filename (SRCDIR, "charango", "data", "ontologies", null);
	try {
		context.add_local_ontology_source (path);
	}
	catch (FileError error) {
		print ("Unable to find ontologies: %s\n", error.message);
	}

	/*var artist_mo = new Charango.Entity(context, "mo:MusicArtist");
	entity.set_string ("rdf:about",
	                   "http://musicbrainz.org/artist/ac241ded-3430-4f42-8451-f78667cc2f52");
	entity.set_string ("foaf:name", "The Aggrolites");
	entity.set_string ("ov:sortName", "Aggrolites, The");*/

	var artist_nmm = new Charango.Entity (context, "nmm:Artist");
	/*entity.set_string ("rdf:about",
	                   "http://musicbrainz.org/artist/ac241ded-3430-4f42-8451-f78667cc2f52");
	entity.set_string ("nmm:artistName", "The Aggrolites");
	entity.set_string ("ov:sortName", "Aggrolites, The");*/

	//artist_mo.dump ();
	artist_nmm.dump ();
	return 0;
}