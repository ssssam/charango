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
	var path = Path.build_filename (SRCDIR, "charango", "data", "ontologies", null);

	try {
		context.add_local_ontology_source (path);
		context.load_namespace ("http://purl.org/ontology/mo/");
	}
	  catch (FileError error) {
		print ("Unable to find ontologies: %s\n", error.message);
		return 1;
	  }
	  catch (ParseError error) {
		print ("Error loading ontology data: %s\n", error.message);
		return 2;
	  }

	var artist_mo = new Charango.Entity (null,
	                                     "http://musicbrainz.org/artist/ac241ded-3430-4f42-8451-f78667cc2f52",
	                                     context.find_class ("http://purl.org/ontology/mo/MusicArtist"));

	var track_mo = new Charango.Entity (null,
	                                    "track:test",
	                                    context.find_class ("http://purl.org/ontology/mo/Track"));

	artist_mo.rdf_type.dump_properties();

	/*artist_mo.set_string ("rdf:about",
	                   );
	artist_mo.set_string ("foaf:name", "The Aggrolites");
	artist_mo.set_string ("ov:sortName", "Aggrolites, The");
	*/

	/* Step 2:
	track_mo.set_resource ("mo:key", Charango.get_entity ("keys:DMinor"));
	*/

	/*var artist_nmm = new Charango.Entity (context, "nmm:Artist");
	entity.set_string ("rdf:about",
	                   "http://musicbrainz.org/artist/ac241ded-3430-4f42-8451-f78667cc2f52");
	entity.set_string ("nmm:artistName", "The Aggrolites");
	entity.set_string ("ov:sortName", "Aggrolites, The");*/

	/*artist_mo.dump ();
	track_mo.dump ();*/
	//artist_nmm.dump ();
	return 0;
}
