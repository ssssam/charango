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
internal List<Class> child_list  = null;

/* This class's known properties; property id is its index in this table.
 * Annotation properties are added to this table when first used on the class.
 */
internal PtrArray    properties;

public bool builtin = false;

internal Ontology ontology;

/* Only stored while awaiting load */
unowned Rdf.Node? this_node;

public Class (Charango.Ontology _ontology,
              int               _id,
              string            _name) {
	ontology = _ontology;
	id = _id;
	name = _name;

	properties = new PtrArray ();
}

public Class.internal (Charango.Ontology _ontology,
                       int               _id,
                       string            _name) {
	this (_ontology, _id, _name);
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

	tracel (2, "ontology", "%s: %s: loading\n", this.ontology.source_file_name, this.name);

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

			if (parent_node.is_resource ()) {
				Charango.Class parent = context.get_class_by_uri (parent_node.get_uri());

				if (main_parent == null)
					main_parent = parent;
				else
					parent_list.prepend (parent);

				parent.child_list.prepend (this);
			}
			else
			if (parent_node.is_blank ()) {
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

public List<Class> get_parents () {
	List<Class> list = this.parent_list.copy();
	foreach (Class c in list) c.ref();
	list.prepend (main_parent);
	return list;
}

public List<Class> get_children () {
	return child_list.copy();
}

public void register_property (Charango.Property property) {
	// FIXME: this is probably actually an ontology warning rather than
	// programmer error
	this.properties.foreach ((p) => {
		if (p == property)
			return;
	});

	this.properties.add (property);

	foreach (Class c in this.child_list)
		c.register_property (property);
}

public Charango.Property get_rdfs_property (string  property_name,
                                            int    *p_index = null)
                         throws OntologyError                       {
	for (uint i=0; i<properties.len; i++) {
		Property p = (Property)properties.index(i);

		if (p.name == property_name) {
			if (p_index != null)
				*p_index = i;
			return p;
		}
	}

	throw new OntologyError.UNKNOWN_PROPERTY
	      ("Class %s has no property '%s'", this.to_string(), property_name);
}

public uint get_rdfs_property_index (string property_name)
            throws OntologyError                           {
	for (uint i=0; i<properties.len; i++) {
		Property p = (Property)properties.index(i);

		if (p.name == property_name)
			return i;
	}

	throw new OntologyError.UNKNOWN_PROPERTY
	          ("Class %s has no property '%s'", this.to_string(), property_name);
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
	print ("rdfs:Class %i '%s:%s': %u properties\n", id, ontology.prefix, name, properties.len);
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

public void dump_properties () {
	for (uint i=0; i<this.properties.len; i++) {
		print ("\t%u: %s\n", i, ((Property)this.properties.index(i)).to_string());
	}
}

}


/**
 * Charango.LiteralTypeClass:
 *
 * Represents an xsd literal type or derivation. These are themselves
 * rdfs classes.
 */

public class Charango.LiteralTypeClass: Class {
	public ValueBaseType literal_value_type;

	public LiteralTypeClass (Charango.Ontology _ontology,
	                         int               _id,
	                         string            _name,
	                         ValueBaseType     _literal_value_type) {
		base (_ontology, _id, _name);
		literal_value_type = _literal_value_type;
	}
}
