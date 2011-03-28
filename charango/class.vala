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

/* Annotation properties have no defined domain; one will be set when the
 * property is set on an entity.
 */
public bool annotation = true;
public int id = -1;
public Charango.Class domain;

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
				throw new ParseError.ONTOLOGY_ERROR
				            ("Unknown domain for property %s: %s",
				             this_node.to_string(),
				             domain_node.to_string());
		}

		stream.next ();
	}

	// Add to domain (class) to get an id. Each Charango.Property only exists in
	// one domain, because id's are class specific. For multiple domains we
	// duplicate the this Property object. Annotation properties may not have a
	// domain; when set on an entity, the property is added to that class.
	//
	if (domain_list.length() > 0) {
		this.annotation = false;
		this.set_domain (domain_list.data);

		unowned List<Charango.Class> domain_node = domain_list.next;
		while (domain_node != null) {
			Charango.Property duplicate = this.copy ();
			duplicate.annotation = false;
			duplicate.set_domain (domain_node.data);
			domain_node = domain_node.next;
		}
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
public string label;
public string comment;

/* RDF allows for multiple inheritance, which poses far few problems in pure
 * data than it does when coding. Since 99% of classes have one parent, this
 * one is kept separately to save on a pointer dereference. main_parent may be
 * null only for rdf:Resource.
 */
internal Class?      main_parent = null;
internal List<Class> parent_list = null;

public bool builtin = false;

internal Ontology ontology;

int property_count = 0;

/* Only stored while awaiting load */
unowned Rdf.Node? this_node;

public Class (Charango.Ontology _ontology,
              int               _id,
              string            _name) {
	ontology = _ontology;
	id = _id;
	name = _name;
}

public Class.internal (Charango.Ontology _ontology,
                       int               _id,
                       string            _name) {
	/* FIXME: is it possible to chain to the default constructor? */
	ontology = _ontology;
	id = _id;
	name = _name;
	builtin = true;
}

public void set_node (Rdf.Node node) {
	this_node = node;
}

public void load (Rdf.Model         model,
                  ref List<Warning> warning_list)
            throws ParseError      {
	Context context = ontology.context;
	Rdf.World *redland = context.redland;

	// Find more data on this class from the ontology
	//
	var template = new Rdf.Statement.from_nodes (ontology.context.redland,
	                                              new Rdf.Node.from_node (this_node),
	                                              null,
	                                              null);
	var stream = model.find_statements (template);

	while (! stream.end()) {
		unowned Rdf.Statement statement = stream.get_object ();
		unowned Rdf.Node arc = statement.get_predicate ();

		// rdfs:label - human-readable name
		//
		if (arc.equals (redland->concept (Rdf.Concept.S_label))) {
			unowned Rdf.Node label_node = statement.get_object ();
			label = label_node.get_literal_value ();
		}

		// rdfs:comment - human-readable description
		//
		else
		if (arc.equals (redland->concept (Rdf.Concept.S_comment))) {
			unowned Rdf.Node comment_node = statement.get_object ();
			comment = comment_node.get_literal_value ();
		}
		else

		// rdfs:subClassOf - parent class
		//
		if (arc.equals (redland->concept (Rdf.Concept.S_subClassOf))) {
			unowned Rdf.Node parent_node = statement.get_object ();

			if (parent_node.get_type() == Rdf.NodeType.RESOURCE) {
				Charango.Class parent = context.get_class_by_uri (parent_node.get_uri());

				if (main_parent == null)
					main_parent = parent;
				else
					parent_list.prepend (parent);
			}
			else
			if (parent_node.get_type() == Rdf.NodeType.BLANK) {
				// No idea what to do here, see for example
				// http://www.isi.edu/~pan/damltime/time-entry.owl#CalendarClockDescription
				var w = new Warning ("Unhandled rdf:subClassOf triple in %s",
				                     this.to_string());
				warning_list.append ((owned)w);
			} else
				throw new ParseError.PARSE_ERROR
				            ("%s: rdf:subClassOf requires URI\n", this.to_string());
		}

		stream.next ();
	}

	if (main_parent == null)
		// FIXME: should be able to access this by a fixed index
		main_parent = context.get_class_by_uri (redland->concept_uri (Rdf.Concept.S_Class));

	this_node = null;
}

public int register_property (Charango.Property property) {
	//print ("%s: register property %s\n", this.name, property.name);
	return property_count ++;
}

public List<Class> get_parent_list () {
	List<Class> list = this.parent_list.copy();
	list.prepend (main_parent);
	return list;
}

public string to_string () {
	var builder = new StringBuilder();

	if (ontology.prefix != null)
		builder.append (ontology.prefix);
	else
		builder.append (ontology.uri);

	builder.append (":");
	builder.append (name);

	return builder.str;
}

public void dump() {
	print ("rdfs:Class %i '%s:%s': %i properties\n", id, ontology.prefix, name, property_count);
}

public void dump_heirarchy (int indent = 0) {
	if (indent > 0) {
		for (int i=0; i<indent; i++)
			print ("   ");
		print ("-> ");
	}
	print ("%s:%s\n", ontology.prefix != null? ontology.prefix: ontology.uri, name);

	// Only permitted for rdfs:Resource class
	if (this.main_parent == null)
		return;

	this.main_parent.dump_heirarchy (indent + 1);

	foreach (Class c in parent_list)
		c.dump_heirarchy (indent + 1);
}

}
