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

/**
 * Charango.RdfsLiteralClass:
 *
 * Represents the class of literal values, ie. rdfs:Literal and all of its
 * descendents. 'storage_type' describes how literal values of this datatype
 * should be stored in a GValue.
 */

internal class Charango.XsdOntology: Charango.Ontology {
	

	public XsdOntology (Charango.Namespace ns) {
		var context = ns.context;

		try {
			base (ns, ns.uri, context.owl_ontology_class, null);
		} catch (RdfError error) { critical (error.message); }

		ns.set_ontology (this);

		add_type ("string", typeof (string));
		add_type ("boolean", typeof (bool));
		add_type ("integer", typeof (int64));
		add_type ("double", typeof (double));
		add_type ("date", typeof (Date));
		add_type ("dateTime", typeof (DateTime));

		add_type ("gYear", typeof (Date));
		add_type ("gDay", typeof (Date));
		add_type ("gMonth", typeof (Date));
		add_type ("float", typeof (float));
		add_type ("decimal", typeof (double));
		add_type ("anyURI", typeof (string));

		// FIXME:
		add_type ("time", typeof (int64));

		// FIXME: the contraints of these derived types get ignored :(
		add_type ("int", typeof (int64));
		add_type ("nonNegativeInteger", typeof (int64));

		// WARNING: don't use xsd:duration, w3c warn against it
		add_type ("duration", typeof (double));
	}

	void add_type (string name,
	               Type   type) {
		var c = new LiteralClass (this.ns, name, type, this.ns.context.max_class_id ++);
		this.ns.class_list.prepend (c);
	}
}

internal class Charango.RdfOntology: Charango.Ontology {
	public RdfOntology (Charango.Namespace ns) {
		var context = ns.context;

		try {
			base (ns, ns.uri, context.owl_ontology_class, null);
		} catch (RdfError error) { critical (error.message); }

		ns.set_ontology (this);

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

		ns.class_list.prepend (context.rdfs_resource);
		ns.class_list.prepend (context.rdfs_class);

		Charango.Class c;

		c = new Class.internal (ns, "Literal", context.max_class_id ++);
		c.main_parent = context.rdfs_resource;
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
