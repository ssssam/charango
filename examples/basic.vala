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
	List<Charango.Warning> warning_list;

	try {
		context.add_local_ontology_source (path);
		context.load_namespace ("http://purl.org/ontology/mo/", out warning_list);
		context.load_namespace ("http://open.vocab.org/terms/", out warning_list);
	}
	  catch (FileError error) {
		print ("Unable to find ontologies: %s\n", error.message);
		return 1;
	  }
	  catch (RdfError error) {
		print ("Error loading ontology data: %s\n", error.message);
		return 2;
	  }

	/*foreach (unowned Warning w in warning_list)
		print ("%s\n", w.message);*/

	Charango.Namespace example_ns = null;
	Charango.Namespace musicbrainz_artist_ns = null;
	try {
		example_ns = new Charango.Namespace (context, "http://example.com/", "example");
		musicbrainz_artist_ns = new Charango.Namespace (context, "http://musicbrainz.org/artist/", "musicbrainz");
	}
	  catch (RdfError error) { warning (error.message); }

	var artist_mo = new Charango.Entity (musicbrainz_artist_ns,
	                                     "http://musicbrainz.org/artist/ac241ded-3430-4f42-8451-f78667cc2f52",
	                                     context.find_class ("http://purl.org/ontology/mo/MusicArtist"));

	var track_mo = new Charango.Entity (example_ns,
	                                    "http://example.com/test",
	                                    context.find_class ("http://purl.org/ontology/mo/Track"));

	artist_mo.set_predicate ("http://xmlns.com/foaf/0.1/name", "The Aggrolites");
	artist_mo.set_predicate ("http://open.vocab.org/terms/sort-name", "Aggrolites, The");

	track_mo.set_predicate ("http://purl.org/ontology/mo/key",
	                        context.find_entity ("http://purl.org/NET/c4dm/keys.owl#DMinor"));

	/*var artist_nmm = new Charango.Entity (context, "nmm:Artist");
	entity.set_string ("rdf:about",
	                   "http://musicbrainz.org/artist/ac241ded-3430-4f42-8451-f78667cc2f52");
	entity.set_string ("nmm:artistName", "The Aggrolites");
	entity.set_string ("ov:sortName", "Aggrolites, The");*/

	artist_mo.dump ();
	track_mo.dump ();
	//artist_nmm.dump ();
	return 0;
}
