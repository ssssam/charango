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

namespace Charango {

/* get_ontology_node_from_model:
 *
 * Assuming @model holds a single ontology definition, find its URI by searching
 * for 'xx rdf:type yy' where yy is an ontology class.
 */
/* FIXME: what's the correct way to do this? I've not yet seen a rule - strategies
 * I can think of are:
 *   - just use the first node
 *   - look for rdf:type definition to an ontology type
 *   - search for a URI that ends in # or / 
 */
Rdf.Node? get_ontology_node_from_model (Rdf.World *redland,
                                        Rdf.Model  model,
                                        string     file_path,
                                        out bool   ignore)
          throws ParseError {
	Rdf.Node? node = null;

	node = model.get_source (redland->concept (Concept.MS_type),
	                         get_owl_ontology_concept (redland));

	if (node == null)
		node = model.get_source (redland->concept (Concept.MS_type),
		                         get_tracker_ontology_concept (redland));

	if (node == null) {
		node = model.get_source (redland->concept (Concept.MS_type),
		                         get_dsc_ontology_concept (redland));

		if (node != null) {
			// Tracker .description file, let's ignore this
			ignore = true;
			return null;
		}
	}

	// No definition, so just use the first node and assume that's the ontology
	//
	if (node == null) {
		Rdf.Stream stream = model.as_stream ();
		unowned Rdf.Statement statement = stream.get_object ();

		if (statement == null)
			throw new ParseError.ONTOLOGY_ERROR ("Empty ontology definition %s\n", file_path);

		node = new Rdf.Node.from_node (statement.get_subject ());
	}

	return node;
}

}

/*
 * Charango.Ontology: class for parsing and ontologies
 */
public class Charango.Ontology: GLib.Object {

internal Charango.Context context;

public bool builtin = false;
public bool external = false;

/**
 * source_file_name: on-disk source of the ontology
 */
public string source_file_name;

/**
 * uri: namespace for this ontology
 */
public string uri;

/**
 * prefix: Ontology prefix
 */
public string prefix;

/* List of ontologies which have contributed to this definition */
protected List<Charango.Ontology> external_def_list = null;

protected List<Charango.Class>    class_list = null;
protected List<Charango.Property> property_list = null;

Rdf.Model? model;

public Ontology (Context _context) {
	context = _context;
}

/* add_class_placeholder:
 *
 * Called when an ontology references a class in another which we know, but have
 * not yet read.
 */
internal Charango.Class add_class_placeholder (string class_name) {
	var c = new Charango.Class  (this, context.max_class_id ++, class_name);
	this.class_list.prepend (c);
	return c;
}

void load_classes_from_iter (Rdf.Iterator      iter,
                             ref List<Warning> warning_list)
     throws ParseError                          {

	while (! iter.end()) {
		unowned Rdf.Node object = iter.get_object ();

		if (object.get_type() == NodeType.RESOURCE) {
			string class_namespace, class_name;
			parse_uri_as_resource_strings (object.get_uri().as_string(),
			                               out class_namespace,
			                               out class_name);

			if (class_namespace == this.uri) {
				// Class defined as part of this ontology; save its node so we
				// query its details in this.complete_load().
				//
				var c = this.get_class_by_name (class_name);
				if (c == null) {
					c = new Charango.Class (this, context.max_class_id ++, class_name);
					class_list.prepend (c);
				}
				c.set_node (object);
			} else {
				// Class defined that is in another namespace. If it's not
				// known by context now it never will be so register as external
				//
				var o = context.get_ontology_by_namespace (class_namespace);
				if (o == null) {
					o = context.add_external_ontology (class_namespace, this);

					var w = new Warning ("%s links to unavailable ontology %s",
					                     this.source_file_name,
					                     class_namespace);
					warning_list.append ((owned)w);
				}

				var c = o.get_class_by_name (class_name);
				if (c == null)
					c = o.add_class_placeholder (class_name);
			}
		} else
		if (object.get_type() == NodeType.BLANK);
			// This is part of maybe a domain list, certainly not a class definition
		else
			throw new ParseError.PARSE_ERROR
			            ("Unexpected node %s in class definition", object.to_string());

		iter.next();
	}
}

void load_properties_from_iter (Rdf.Iterator iter)
     throws ParseError                             {
	while (!iter.end()) {
		unowned Rdf.Node object = iter.get_object ();

		if (object.get_type() == NodeType.RESOURCE) {
			var rdfs_property = new Charango.Property (this, object);
			property_list.prepend (rdfs_property);
		}
		else
			throw new ParseError.PARSE_ERROR
			            ("Unexpected node %s in property definition", object.to_string());

		iter.next();
	}
}

/* has_data:
 * false if we don't actually have this ontology's data; only allowed if it's
 * built in or a placeholder that was referenced from an ontology we do know.
 */
internal bool has_data () {
	if (model != null) {
		warn_if_fail (! external);
		return true;
	} else {
		warn_if_fail (builtin || external);
		return false;
	}
}

/* load_from_model:
 * Initial read of ontology definition */
internal void load_from_model (owned Rdf.Model _model,
                               string          file_name,
                               Rdf.Node        this_node)
              throws ParseError                           {
	Rdf.World *redland = context.redland;

	model = (owned) _model;
	source_file_name = file_name;
	uri = this_node.get_uri().to_string();

	// Ensure URI has # or / terminator
	//
	unichar terminator = uri[uri.length-1];
	if (terminator != '#' && terminator != '/')
		uri += "#";

	// Find label/prefix. We look for:
	//   - rdfs:label
	//   - tracker:prefix
	Rdf.Node prefix_node;
	prefix_node = model.get_target (this_node,
	                                get_tracker_prefix_concept (redland));
	if (prefix_node == null)
		prefix_node = model.get_target (this_node,
		                                redland->concept (Concept.S_label));
	if (prefix_node != null) {
		prefix = prefix_node.get_literal_value ();
	}

	// Further properties for the ontology:
	//   http://purl.org/dc/elements/1.1/title
	//   http://purl.org/dc/elements/1.1/description
	//   http://purl.org/dc/elements/1.1/date
	//   http://www.w3.org/2000/01/rdf-schema#comment

}

/* initial_load:
 * 
 * Read class and property definitions.
 * this.external */
internal void initial_load (ref List<Warning> warning_list)
         throws ParseError

         /* external ontologies have nothing to load from */
         requires (this.external == false)
         requires (this.model != null)
{
	Rdf.World *redland = context.redland;

	tracel (1, "ontology", "%s: initial read\n", this.source_file_name);

	// Read class list, use each triple of either form:
	//   C :type rdfs:Class
	//   C :type owl:Class
	Rdf.Iterator iter;
	iter = model.get_sources (redland->concept (Concept.MS_type),
	                          redland->concept (Concept.S_Class));
	load_classes_from_iter (iter, ref warning_list);

	iter = model.get_sources (redland->concept (Concept.MS_type),
	                          get_owl_class_concept (redland));
	load_classes_from_iter (iter, ref warning_list);

	// Read property list, use each triple of one of these forms:
	//  C :type rdf:Property
	//  C :type owl:ObjectProperty
	//  C :type owl:DatatypeProperty
	// Note that the last two are mutually exclusive (and both imply the first).
	//
	// FIXME: enforce the rules of them, ie. mark the property as datatype-only
	// or object-relationship-only. Although it's hard to think of a reason to
	// enforce it when it's not a requirement to even use Owl.
	iter = model.get_sources (redland->concept (Concept.MS_type),
	                          redland->concept (Concept.MS_Property));
	load_properties_from_iter (iter);

	iter = model.get_sources (redland->concept (Concept.MS_type),
	                          get_owl_datatype_property_concept (redland));
	load_properties_from_iter (iter);

	iter = model.get_sources (redland->concept (Concept.MS_type),
	                          get_owl_object_property_concept (redland));
	load_properties_from_iter (iter);
}

/* complete_load: connect up the property and class objects */
internal void complete_load (ref List<Warning> warning_list)
         throws ParseError     {
	tracel (1, "ontology", "%s: completing load\n", this.source_file_name);

	try {
		foreach (Class c in class_list)
			if (c.builtin == false)
				c.load (model, ref warning_list);
		foreach (Property p in property_list)
			p.load (model);
	}
	catch (ParseError e) {
		// FIXME: is it possible to use e's error code for our new error?
		throw new ParseError.PARSE_ERROR
		            ("%s while loading ontology %s", e.message, this.uri);
	}
	model = null;
}

internal Charango.Class? get_class_by_name (string name) {
	foreach (Charango.Class c in class_list) {
		if (c.name == name) {
			return c;
		}
	}

	return null;
}

public void dump () {
	print ("charango ontology: %s [%s]\n", uri.to_string(), prefix);
	foreach (Charango.Class rdfs_class in class_list) {
		assert (rdfs_class != null);
		print ("\tclass %i: ", 1); rdfs_class.dump();
	}
	foreach (Charango.Property rdfs_property in property_list) {
		print ("\tproperty %i: ", 1); rdfs_property.dump();
	}
}

}
