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

/* Concepts are specialised forms of entity, which have their own Vala class
 * because they are relevant to ontology structure. */
public enum Charango.ConceptType {
	ONTOLOGY = 0,
	CLASS = 1,
	PROPERTY = 2,
	ENTITY = 3
}

public class Charango.Class: Entity {

public int id;
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

public Class (Charango.Namespace ns,
              string             uri,
              Charango.Class     rdf_type,
              int                id) {
	base (ns, uri, rdf_type);

	this.id = id;

	// Give a default superclass; this will be overwritten if/when
	// rdfs:subClassOf is read
	this.main_parent = ns.context.rdfs_resource;

	this.initialize_properties ();
}

internal Class.internal (Charango.Namespace ns,
                         string             name,
                         int                id) {
	string uri = ns.uri + name;

	base  (ns, uri, ns.context.rdfs_class);

	this.id = id;
	this.main_parent = ns.context.rdfs_resource;
	this.builtin = true;

	this.initialize_properties ();
}

internal Class.prototype (Charango.Namespace ns,
                          string             uri,
                          int                id) {
	base.prototype (ns, uri);

	this.id = id;

	this.initialize_properties ();
}

void initialize_properties () {
	this.properties = new PtrArray ();

	// Hardcoded properties; we rely on these having a fixed index to work
	// around chicken-and-egg lookup problems.
	properties.add (this.ns.context.rdf_type);
}

internal ConceptType get_concept_type ()
                     throws Charango.RdfError {
	Charango.Class? concept_type = this;

	while (concept_type != null) {
		switch (concept_type.uri) {
			case "http://www.w3.org/2002/07/owl#Ontology":
				return ConceptType.ONTOLOGY;
			case "http://www.w3.org/2000/01/rdf-schema#Class":
				return ConceptType.CLASS;
			case "http://www.w3.org/1999/02/22-rdf-syntax-ns#Property":
				return ConceptType.PROPERTY;
			case "http://www.w3.org/2000/01/rdf-schema#Resource":
				return ConceptType.ENTITY;
		}

		if (concept_type.main_parent == concept_type)
			break;

		// This could theoretically miss subclasses that have multiple
		// inheritance, but I think you would deserve to have problems
		concept_type = concept_type.main_parent;
	}

	throw new RdfError.INTERNAL_ERROR
	  ("'%s' has somehow ruptured the fabric of the universe", this.uri);
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

public Charango.Property intern_property (string  property_uri,
                                          uint   *p_index = null)
                         throws RdfError {
	/* FIXME: storing properties would be a lot more efficient in a B-tree
	 * or some such structure.
	 */
	Property? p = null;
	uint i;

	for (i=0; i<properties.len; i++) {
		if (((Property)properties.index(i)).uri == property_uri) {
			p = (Property)properties.index(i);
			break;
		}
	}

	if (p == null) {
		p = this.ns.context.find_property_with_error (property_uri);
		properties.add (p);
	}

	if (p_index != null)
		*p_index = i;

	return p;
}

internal Charango.Property get_property_by_index (uint index) {
	return (Charango.Property) properties.index (index);
}

public override void dump () {
	print ("rdfs:Class %i '%s:%s': %u properties\n", id, this.ns.prefix, name, properties.len);
}

public void dump_heirarchy (int indent = 0) {
	if (indent > 0) {
		for (int i=0; i<indent; i++)
			print ("   ");
		print ("-> ");
	}
	print ("%s:%s\n", this.ns.prefix != null? this.ns.prefix: this.ns.uri, name);

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

public class Charango.LiteralClass: Charango.Class {
	public Type storage_type;

	public LiteralClass (Charango.Namespace ns,
	                     string             name,
	                     Type               storage_type,
	                     int                id) {
		string uri = ns.uri + name;

		base (ns, uri, ns.context.rdfs_class, id);

		this.storage_type = storage_type;
	}
}

