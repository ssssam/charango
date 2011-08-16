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

internal class Charango.XsdOntology: Charango.Ontology {
	struct TypeMapping {
		string        name;
		ValueBaseType type;
	}

	public XsdOntology (Charango.Namespace ns) {
		var context = ns.context;

		try {
			base (ns, ns.uri, context.owl_ontology_class, null);
		} catch (RdfError error) { critical (error.message); }

		ns.set_ontology (this);

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
			// FIXME:
			{ "time", ValueBaseType.INT64 },

			// FIXME: the contraints of these derived types get ignored :(
			{ "int", ValueBaseType.INT64 },
			{ "nonNegativeInteger", ValueBaseType.INT64 }
		};

		foreach (TypeMapping type in (TypeMapping[]) mappings) {
			ns.class_list.prepend (new LiteralTypeClass (
				ns,
				type.name,
				type.type,
				context.max_class_id ++
			));
		}
	}
}

internal class Charango.RdfOntology: Charango.Ontology {
	public RdfOntology (Charango.Namespace ns) {
		var context = ns.context;

		try {
			base (ns, ns.uri, context.owl_ontology_class, null);
		} catch (RdfError error) { critical (error.message); }

		ns.set_ontology (this);

		ns.class_list.prepend (context.rdf_resource);

		context.rdf_property = new Class.internal (ns, "Property", context.max_class_id ++);
		ns.class_list.prepend (context.rdf_property);

		ns.class_list.prepend (new Class.internal (ns, "List", context.max_class_id ++));
	}
}

internal class Charango.RdfsOntology: Ontology {
	public RdfsOntology (Charango.Namespace ns) {
		var context = ns.context;

		try {
			base (ns, ns.uri, context.owl_ontology_class, null);
		} catch (RdfError error) { critical (error.message); }

		ns.class_list.prepend (context.rdfs_class);

		/* FIXME: not sure what to do about this - is it really correct
		 * rdfs:Resource is valid as well as rdf:Resource and means the
		 * same thing ?? */
		ns.class_list.prepend (new Class.internal (ns, "Resource", context.max_class_id ++));

		Charango.Class c;

		c = new Class.internal (ns, "Literal", context.max_class_id ++);
		c.main_parent = context.rdf_resource;
		ns.class_list.prepend (c);

		c = new Class.internal (ns, "Datatype", context.max_class_id ++);
		c.main_parent = context.rdfs_class;
		ns.class_list.prepend (c);
	}
}

internal class Charango.OwlOntology: Charango.Ontology {
	public OwlOntology (Charango.Namespace ns) {
		var context = ns.context;

		try {
			base (ns, ns.uri, context.owl_ontology_class, null);
		} catch (RdfError error) { critical (error.message); }

		ns.class_list.prepend (context.owl_ontology_class);

		ns.class_list.prepend (new Class.internal (ns, "Class", context.max_class_id ++));

		Charango.Class c;
		c = new Class.internal (ns, "Class", context.max_class_id ++);
		c.main_parent = context.rdfs_class;
		ns.class_list.prepend (c);

		c = new Class.internal (ns, "AnnotationProperty", context.max_class_id ++);
		c.main_parent = context.find_class ("http://www.w3.org/1999/02/22-rdf-syntax-ns#Property");
		ns.class_list.prepend (c);

		c = new Class.internal (ns, "DatatypeProperty", context.max_class_id ++);
		c.main_parent = context.find_class ("http://www.w3.org/1999/02/22-rdf-syntax-ns#Property");
		ns.class_list.prepend (c);

		c = new Class.internal (ns, "FunctionalProperty", context.max_class_id ++);
		c.main_parent = context.find_class ("http://www.w3.org/1999/02/22-rdf-syntax-ns#Property");
		ns.class_list.prepend (c);

		c = new Class.internal (ns, "ObjectProperty", context.max_class_id ++);
		c.main_parent = context.find_class ("http://www.w3.org/1999/02/22-rdf-syntax-ns#Property");
		ns.class_list.prepend (c);

		try {

		c = new Class.internal (ns, "SymmetricProperty", context.max_class_id ++);
		c.main_parent = ns.find_local_class ("http://www.w3.org/2002/07/owl#ObjectProperty");
		ns.class_list.prepend (c);

		} catch (RdfError error) { critical (error.message); }
	}
}
