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

public Rdf.Node get_owl_ontology_class (Rdf.World redland) {
	return new Rdf.Node.from_uri_string
	                     (redland, "http://www.w3.org/2002/07/owl#Ontology");
}

public Rdf.Node get_tracker_ontology_class (Rdf.World redland) {
	return new Rdf.Node.from_uri_string
	                     (redland, "http://www.tracker-project.org/ontologies/tracker#Ontology");
}

public Rdf.Node get_dsc_ontology_class (Rdf.World redland) {
	return new Rdf.Node.from_uri_string
	                     (redland, "http://www.tracker-project.org/temp/dsc#Ontology");
}

public Rdf.Node get_tracker_prefix_predicate (Rdf.World redland) {
	return new Rdf.Node.from_uri_string
	                     (redland, "http://www.tracker-project.org/ontologies/tracker#prefix");
}

/* Built-in types. Note these can still be added to from files. */
public class RdfOntology: Ontology {
	public RdfOntology (Context _context) {
		base (_context);
		builtin = true;
		uri = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
		prefix = "rdf";

		class_list.prepend (new Class.internal (context.max_class_id ++, "Property"));
	}
}

public class RdfsOntology: Ontology {
	public RdfsOntology (Context _context) {
		base (_context);
		builtin = true;
		uri = "http://www.w3.org/2000/01/rdf-schema#";
		prefix = "rdfs";

		class_list.prepend (new Class.internal (context.max_class_id ++, "Resource"));
		class_list.prepend (new Class.internal (context.max_class_id ++, "Class"));
	}
}

public class TrackerOntology: Ontology {
	public TrackerOntology (Context _context) {
		base (_context);

		builtin = true;

		uri = "http://www.tracker-project.org/ontologies/tracker#";
		prefix = "tracker";

		class_list.prepend (new Class.internal (context.max_class_id ++, "Namespace"));
	}
}

}