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
 * Charango.RdfsProperty:
 * Represents an Rdf:Property specific to one class. If the domain of the
 * property takes in more than one class, a different Rdf:Property object
 * will be created for each (because property id's are per-class).
 */
public class Charango.Property: GLib.Object {

Ontology ontology;

public Charango.Class domain;
public int            id;

public string name;
public string label;

unowned Rdf.Node this_node;

public Property (Ontology _ontology,
                 Rdf.Node _this_node) {
	ontology = _ontology;
	this_node = _this_node;

	name = get_name_from_uri (this_node.get_uri().as_string());
}

public void load (Rdf.Model model)
                  throws ParseError {
	Context context = ontology.context;
	Rdf.World *redland = context.redland;

	List <Charango.Class> domain_list = null;

	var template = new Rdf.Statement.from_nodes (redland,
	                                             new Rdf.Node.from_node (this_node),
	                                             null,
	                                             null);
	var stream = model.find_statements (template);
	while (! stream.end()) {
		unowned Rdf.Statement statement = stream.get_object ();
		unowned Rdf.Node arc = statement.get_predicate ();

		//print ("object type: %i\n", statement.get_object().get_type());

		if (arc.equals (redland->concept (Rdf.Concept.S_label))) {
			// rdfs:label - human-readable name
			unowned Rdf.Node label_node = statement.get_object ();
			label = label_node.get_literal_value ();
		}
		else
		if (arc.equals (redland->concept (Rdf.Concept.S_domain))) {
			// rdfs:domain - classes of which this property is a member
			unowned Rdf.Node domain_node = statement.get_object ();
			Class? domain = null;
			domain = context.get_class_by_uri (domain_node.get_uri());
			if (domain != null)
				domain_list.append (domain);
			else
				throw new ParseError.PARSE_ERROR ("Unknown domain for property %s: %s",
				                                  this_node.to_string(),
				                                  domain_node.to_string());
		}

		stream.next ();
	}

	// Add to domain (class) to get an id. Each Charango.Property only exists in
	// one domain, because id's are class specific. For multiple domains we
	// duplicate the this Property object.
	if (domain_list.length() == 0)
		throw new ParseError.PARSE_ERROR ("No domain listed for property %s",
		                                  this_node.to_string());
	this.set_domain (domain_list.data);

	unowned List<Charango.Class> domain_node = domain_list.next;
	while (domain_node != null) {
		Charango.Property duplicate = this.copy ();
		duplicate.set_domain (domain_node.data);
		domain_node = domain_node.next;
	}
}

public Property copy () {
	Property copy = new Charango.Property (ontology, this_node);
	copy.label = label;
	return copy;
}

void set_domain (Charango.Class _domain) {
	domain = _domain;
	id = domain.register_property (this);
}

public void dump() {
	print ("rdf:Property %i '%s:%s' in domain %s:%s\n",
	       id, ontology.prefix, name, domain.ontology.prefix, domain.name);
}

}

/**
 * Charango.RdfsClass: represents an rdfs:Class
 */

/* How to parse a class, from the ontology ..
 * * Need to look out for the key predicates:
 *    - rdf:type == rdfs:Class
 *    - rdfs:label -> class name
 *    - rdfs:subClassOf -> parent
 */

public class Charango.Class: GLib.Object {

public int id;
public string name;

public bool builtin = false;

internal Ontology ontology;

int property_count = 0;

/* Only stored while awaiting load */
unowned Rdf.Node? this_node;

public Class (Ontology _ontology,
              Rdf.Node _this_node,
              int      _id) {
	ontology = _ontology;
	this_node = _this_node;
	id = _id;

	// Get name from uri fragment
	unowned string uri_string = this_node.get_uri().as_string ();
	int fragment_start = uri_string.index_of_char('#');
	return_if_fail (fragment_start > -1);
	return_if_fail (fragment_start < uri_string.length - 1);
	name = uri_string[fragment_start + 1: uri_string.length];
}

public Class.internal (int _id, string _name) {
	id = _id;
	name = _name;
	builtin = true;
}

public void load (Rdf.Model model) {
	// Find all our properties from the ontology
	var statement = new Rdf.Statement.from_nodes (ontology.context.redland,
	                                              new Rdf.Node.from_node (this_node),
	                                              null,
	                                              null);
	var stream = model.find_statements (statement);
	/*stream.print (stdout); */

	this_node = null;
}

public int register_property (Charango.Property property) {
	//print ("%s: register property %s\n", this.name, property.name);
	return property_count ++;
}

public void dump() {
	print ("rdfs:Class %i '%s:%s'\n", id, ontology.prefix, name);
}

}