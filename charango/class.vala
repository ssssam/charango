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

/**
 * Charango.RdfsClass: represents an rdfs:Class
 */

/* How to parse a class, from the ontology ..
 * * Need to look out for the key predicates:
 *    - rdf:type == rdfs:Class
 *    - rdfs:label -> class name
 *    - rdfs:subClassOf -> parent
 */

class Charango.Class: GLib.Object {

Ontology ontology;

public string name   {get; private set; }

public Class(Ontology _ontology, Rdf.Model model, Rdf.Node node) {
	ontology = _ontology;
	name = _name;

	/* Find all our properties from the ontology */
	var statement = new Rdf.Statement.from_nodes (ontology.redland, node, null, null);
	var stream = model.find_statements (statement);
	stream.print (stdout);
}

public void dump() {
	print ("rdfs:Class '%s:%s'\n", ontology.prefix, name);
}

}