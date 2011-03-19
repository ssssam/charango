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

using Rdf;

/* Tracker ontology support: http://www.tracker-project.org/ontologies/tracker#
 * (This is not a hard dep on tracker, because it's only their ontologies we are using here)
 */

namespace Charango {

public Rdf.Node get_tracker_ontology_class (Rdf.World redland) {
	return new Rdf.Node.from_uri_string
	                     (redland, "http://www.tracker-project.org/ontologies/tracker#Ontology");
}

public Rdf.Node get_tracker_prefix_predicate (Rdf.World redland) {
	return new Rdf.Node.from_uri_string
	                     (redland, "http://www.tracker-project.org/ontologies/tracker#prefix");
}

}
