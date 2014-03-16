# test-sparql-find-root-pattern
# Copyright (C) 2014  Sam Thursfield
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

Q1 = ("PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns> "
      "PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> "
      "SELECT ?class ?property {"
      "   ?class a rdfs:Class ."
      "   ?property a rdf:Property ; "
      "       rdfs:domain ?class"
      "} ORDER BY ?class ?property")

# music-1.sparql
Q2 = (
        "PREFIX nie: <http://www.semanticdesktop.org/ontologies/2007/01/19/nie#> "
        "PREFIX nmm: <http://www.tracker-project.org/temp/nmm#> "
        "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns/> "
        "PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> "

        "SELECT "

# RAPTOR cannot handle COALESCE in selection
#        "    COALESCE(?album_artist_name, ?rec_artist_name) AS ?artist_name "
        "    ?album_artist_name "

        "    ?rec_artist_name "
        "    ?rec_name ?album_name ?track_number "
        "WHERE { "
        "    ?rec_artist nmm:artistName ?rec_artist_name . "
        " "
        "    { "
        "        SELECT "
        "            ?rec_name ?rec_artist "
        "            ?album_name "
        "            ?album_artist_name "
        "            ?track_number "
        "        WHERE { "
        "            { "
        # RAPTOR cannot handle comments either
        #"                # Get ?album_artist_name, which will be 'Various Artists' in "
        #"                # some cases. It would be nice to abstract the logic of this "
        #"                # into a function somehow. "
        "                { "
        "                    SELECT "
        "                        ?album "
# For RAPTOR, again
#        "                        IF( "
#        "                            COUNT(?album_artist) > 2, "
#        "                            'Various Artists', ?album_artist_name) "
#        "                        AS ?album_artist_name "
        "                    WHERE { "
        "                        ?album a nmm:MusicAlbum ; "
        "                            nmm:albumArtist ?album_artist . "
        "                        ?album_artist nmm:artistName ?album_artist_name . "
        "                    } "
        "                    GROUP BY ?album "
        "                } "
        " "
        "                ?album nie:title ?album_name . "
        " "
        "                ?track a nmm:MusicPiece ; "
        "                    nmm:musicAlbum ?album ; "
        "                    nmm:performer ?rec_artist ; "
        "                    nie:title ?rec_name ; "
        "                    nmm:trackNumber ?track_number . "
        "            } "
        "            UNION "
        #"            # Tracks by that are not on any albums. "
        "            { "
        "                ?rec a nmm:MusicPiece ; nie:title ?rec_name . "
        "                ?rec nmm:performer ?rec_artist . "
        # RAPTOR doesn't seem to support this
        #"                FILTER (NOT EXISTS { ?rec nmm:musicAlbum ?rec_album }) "
        "            } "
        "        } "
        "    } "
        "} "
        #"# Unbound values sort first, so this results in "
        #"# all the tracks which are not an album coming *above* those "
        #"# which are. "
        "ORDER BY ?artist_name ?album_name ?track_number")

import subprocess
import tempfile

def run_test(query):
    process = subprocess.Popen(
            './sparql-find-root-pattern',
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE)
    process.stdin.write(query.encode('utf-8'))
    process.stdin.close()
    status = process.wait()
    assert status == 0
    result = process.stdout.read()
    result = result.decode('utf-8')
    print("Query: %s" % query)
    print("Root term -> %s" % result)

#run_test(Q1)
run_test(Q2)
