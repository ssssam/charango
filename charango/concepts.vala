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

/* Built-in types and universal constants. Note that these objects will
 * be fleshed out further when their ontology definition is loaded. */

/* FIXME: we currently pretend that rdfs:Resource does not exist and it's
 * exactly the same as rdf:Resource. How true is this? 
 */
internal class Charango.RdfResource: Charango.Class {
	public RdfResource () {
		base.prototype ("http://www.w3.org/1999/02/22-rdf-syntax-ns#Resource");
		this.builtin = true;
	}
}

internal class Charango.RdfsClass: Charango.Class {
	public RdfsClass () {
		base.prototype ("http://www.w3.org/2000/01/rdf-schema#Class");
		this.builtin = true;
	}
}

/* FIXME: here's a nice Vala bug!!! If I define
 * OwlOntologyClass and OwlOntology, Vala doesn't know that the class of
 * OwlOntology needs a different name, so we get a duplicate definition .
 */
public class Charango.OwlOntologyClass2: Charango.Class {
	public OwlOntologyClass2 (Charango.Class rdfs_class) {
		base.prototype ("http://www.w3.org/2002/07/owl#Ontology");
		this.rdf_type = rdfs_class;
		this.builtin = true;
	}
}

internal class Charango.XsdOntology: Ontology {
	struct TypeMapping {
		string        name;
		ValueBaseType type;
	}

	public XsdOntology (Context context) {
		try {
			base (context,
			      "http://www.w3.org/2001/XMLSchema#",
			      context.owl_ontology_class,
			      null,
			      "xsd");
		} catch (ParseError error) { critical (error.message); }

		builtin = true;

		/* FIXME: if you take away the const, Vala (0.12.0) gives an error:
		 *   "Expected array element, got array initializer list"
		 * That's completely unhelpful. Something like "Struct initialisation
		 * is only permitted for constants" would be better.
		 */
		const TypeMapping mappings[] = {
			// Primitive types - Tracker's subset
			{ "string", ValueBaseType.STRING },
			{ "boolean", ValueBaseType.BOOLEAN },
			{ "integer", ValueBaseType.INT64 },
			{ "double", ValueBaseType.DOUBLE },
			{ "date", ValueBaseType.DATE },
			{ "dateTime", ValueBaseType.DATETIME },

			// Other primitives
			{ "duration", ValueBaseType.DOUBLE },
			{ "gYear", ValueBaseType.DATE },
			{ "gDay", ValueBaseType.DATE },
			{ "gMonth", ValueBaseType.DATE },
			{ "float", ValueBaseType.FLOAT },
			{ "decimal", ValueBaseType.DOUBLE },
			{ "anyURI", ValueBaseType.STRING },

			// FIXME: the contraints of these derived types get ignored :(
			{ "int", ValueBaseType.INT64 },
			{ "nonNegativeInteger", ValueBaseType.INT64 }
		};

		foreach (TypeMapping type in (TypeMapping[]) mappings) {
			class_list.prepend (new LiteralTypeClass (
				this,
				context.max_class_id ++,
				type.name,
				type.type
			));
		}
	}
}

internal class Charango.RdfOntology: Ontology {
	public RdfOntology (Context context) {
		try {
			base (context,
			      "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
			      context.owl_ontology_class,
			      null,
			      "rdf");
		} catch (ParseError error) { critical (error.message); }

		builtin = true;

		context.rdf_resource.owner = this;
		class_list.prepend (context.rdf_resource);

		class_list.prepend (new Class.internal (this, context.max_class_id ++, "Property"));
		class_list.prepend (new Class.internal (this, context.max_class_id ++, "List"));
	}
}

internal class Charango.RdfsOntology: Ontology {
	public RdfsOntology (Context context) {
		try {
			base (context,
			      "http://www.w3.org/2000/01/rdf-schema#",
			      context.owl_ontology_class,
			      null,
			      "rdfs");
		} catch (ParseError error) { critical (error.message); }

		builtin = true;

		context.rdfs_class.owner = this;
		class_list.prepend (context.rdfs_class);

		class_list.prepend (new Class.internal (this, context.max_class_id ++, "Resource"));

		Charango.Class c;

		c = new Class.internal (this, context.max_class_id ++, "Literal");
		c.main_parent = context.rdf_resource;
		class_list.prepend (c);

		c = new Class.internal (this, context.max_class_id ++, "Datatype");
		c.main_parent = context.rdfs_class;
		class_list.prepend (c);
	}
}

internal class Charango.OwlOntology: Charango.Ontology {
	public OwlOntology (Context context) {
		try {
			base (context,
			      "http://www.w3.org/2002/07/owl#",
			      context.owl_ontology_class,
			      null,
			      "owl");
		} catch (ParseError error) { critical (error.message); }

		this.builtin = true;

		context.owl_ontology_class.owner = this;
		class_list.prepend (context.owl_ontology_class);

		this.class_list.prepend (new Class.internal (this, context.max_class_id ++, "Class"));

		Charango.Class c;
		c = new Class.internal (this, context.max_class_id ++, "Class");
		c.main_parent = context.rdfs_class;
		this.class_list.prepend (c);

		c = new Class.internal (this, context.max_class_id ++, "AnnotationProperty");
		c.main_parent = context.find_class ("http://www.w3.org/1999/02/22-rdf-syntax-ns#Property");
		this.class_list.prepend (c);

		c = new Class.internal (this, context.max_class_id ++, "DatatypeProperty");
		c.main_parent = context.find_class ("http://www.w3.org/1999/02/22-rdf-syntax-ns#Property");
		this.class_list.prepend (c);

		c = new Class.internal (this, context.max_class_id ++, "FunctionalProperty");
		c.main_parent = context.find_class ("http://www.w3.org/1999/02/22-rdf-syntax-ns#Property");
		this.class_list.prepend (c);

		c = new Class.internal (this, context.max_class_id ++, "ObjectProperty");
		c.main_parent = context.find_class ("http://www.w3.org/1999/02/22-rdf-syntax-ns#Property");
		this.class_list.prepend (c);

		try {
		c = new Class.internal (this, context.max_class_id ++, "SymmetricProperty");
		c.main_parent = this.find_local_class ("http://www.w3.org/2002/07/owl#ObjectProperty");
		this.class_list.prepend (c);
		} catch (OntologyError error) { critical (error.message); }
	}
}

namespace Charango {

public Rdf.Node get_owl_ontology_concept (Rdf.World redland) {
	return new Rdf.Node.from_uri_string
	                     (redland, "http://www.w3.org/2002/07/owl#Ontology");
}

public Rdf.Node get_owl_class_concept (Rdf.World redland) {
	return new Rdf.Node.from_uri_string
	                     (redland, "http://www.w3.org/2002/07/owl#Class");
}

public Rdf.Node get_owl_datatype_property_concept (Rdf.World redland) {
	return new Rdf.Node.from_uri_string
	                     (redland, "http://www.w3.org/2002/07/owl#DatatypeProperty");
}

public Rdf.Node get_owl_object_property_concept (Rdf.World redland) {
	return new Rdf.Node.from_uri_string
	                     (redland, "http://www.w3.org/2002/07/owl#ObjectProperty");
}

public Rdf.Node get_tracker_ontology_concept (Rdf.World redland) {
	return new Rdf.Node.from_uri_string
	                     (redland, "http://www.tracker-project.org/ontologies/tracker#Ontology");
}

public Rdf.Node get_dsc_ontology_concept (Rdf.World redland) {
	return new Rdf.Node.from_uri_string
	                     (redland, "http://www.tracker-project.org/temp/dsc#Ontology");
}

public Rdf.Node get_tracker_prefix_concept (Rdf.World redland) {
	return new Rdf.Node.from_uri_string
	                     (redland, "http://www.tracker-project.org/ontologies/tracker#prefix");
}

}