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
 * Charango.Property:
 * 
 * Represents an Rdfs:Property or subproperty
 */
public class Charango.Property: GLib.Object {

Ontology ontology;

public string name;
public string label;

/* type: basic type of literal stored by the property, or ValueBaseType.RESOURCE */
Charango.ValueBaseType type;

/* range: actual range of the resource. Note that XSD literal types and derivations share
 *        an id space with RDFS classes.
 */
Charango.Class range;

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

	List<Charango.Class> domain_list = null;

	var template = new Rdf.Statement.from_nodes (redland,
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

		// rdfs:domain - classes of which this property is a member
		//
		else
		if (arc.equals (redland->concept (Rdf.Concept.S_domain))) {
			unowned Rdf.Node domain_node = statement.get_object ();
			if (domain_node.is_resource ()) {
				Class? domain = null;
				domain = context.get_class_by_uri (domain_node.get_uri());
				if (domain != null) {
					domain_list.append (domain);
				} else
					throw new ParseError.ONTOLOGY_ERROR
					            ("Unknown domain for property %s: %s",
					             this_node.to_string(),
					             domain_node.to_string());
			} else
			if (domain_node.is_blank ()) {
				// FIXME: handle lists here
			} else {
				throw new ParseError.PARSE_ERROR
				            ("%s: rdf:domain requires URI\n", this.to_string());
			}
		}

		// rdfs:range - type of this property.
		//
		else
		if (arc.equals (redland->concept (Rdf.Concept.S_range))) {
			unowned Rdf.Node range_node = statement.get_object ();
			if (range_node.is_resource ()) {
				Class? range = null;
				range = context.get_class_by_uri (range_node.get_uri());

				if (range is Charango.LiteralTypeClass)
					type = ((Charango.LiteralTypeClass)range).literal_value_type;
				else
					type = ValueBaseType.RESOURCE;
			} else if (range_node.is_blank ()) {
				// FIXME: handle lists here ... are there many properties with range
				// a list? mo:similar_to is one.
			} else {
				throw new ParseError.PARSE_ERROR
				            ("%s: rdfs:range requires URI\n", this.to_string());
			}
		}

		stream.next ();
	}

	// Register this property with the classes in its specific domain and their
	// subclasses. The property can still be set on other classes (annonation
	// properties are intended to be used that way).
	foreach (Charango.Class domain in domain_list)
		domain.register_property (this);
}

public string to_string () {
	return "%s:%s".printf (ontology.prefix ?? ontology.uri, name);
}

public void dump () {
	print ("rdf:Property '%s'\n", this.to_string());
}

}


