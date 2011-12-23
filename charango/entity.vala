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

namespace Charango {

/**
 * Charango.Entity: a data 'object'
 * 
 * More precisely, a #Charango.Entity is an instance of an rdfs:Class -
 * an rdf:Resource which has had an rdf:type specified.
 */
/* FIXME: Ideally, this would be a MiniObject type. We don't need signals
 * or properties, it's a model. In general Models should be MiniObjects, in
 * fact (I've been reading about MVC recently :) perhaps there should be a 
 * GDataModel base class that specifically cannot emit signals, because
 * a data model should not need them.
 */
 
 /* It would be cool to have this as a 'magic' GObject subclass, in fact.
  * Since the namespace of GObject properties is completely clean we don't
  * have to worry about namespace clashes (and the property names will be
  * key URI's :). We could have magic get, set, enumerate etc. property
  * functions where all class properties and all assigned annotation
  * properties are accessible & listed.
  * - Would property notifications not clash horribly with the store's
  *   change notifications? Actually no, they could coexist because the
  *   store would still notify on changes, just that the object optionally
  *   would as well.
  */

public class Entity: Object {

public string uri;
public string? key_uri;

internal Charango.Namespace ns;

/* Use a GenericArray instead of ValueArray so we can store null values */
private GenericArray<GLib.Value?> data;

/* FIXME: 'name' could just be a pointer to the fragment part of the uri string */
public string? name;

public Charango.Class rdf_type {
	get { return (Charango.Class) get_predicate_by_index(0).get_object(); }
	set { set_predicate_by_index (0, value); }
}

public Entity (Charango.Namespace ns,
               string             uri,
               Charango.Class     rdf_type) {
	this.ns = ns;
	this.data = new GenericArray<GLib.Value?>();

	this.rdf_type = rdf_type;

	this.set_uri (uri);

	this.name = get_name_from_uri (uri);

	if (this.ns.prefix != null)
		this.key_uri = this.ns.prefix + ":" + this.uri.slice (this.ns.uri.length, this.uri.length);

	Value.register_transform_func (typeof (Entity),
	                               typeof (string),
	                               this.to_string_value);
}

public Entity.prototype (Charango.Namespace ns,
                         string             uri) {
	this.uri = uri;
	this.ns = ns;
	this.data = new GenericArray<GLib.Value?>();

	this.rdf_type = ns.context.rdfs_resource;

	this.name = get_name_from_uri (uri);

	if (this.ns.prefix != null)
		this.key_uri = this.ns.prefix + ":" + this.uri.slice (this.ns.uri.length, this.uri.length);

	Value.register_transform_func (typeof (Entity),
	                               typeof (string),
	                               this.to_string_value);
}

/* Assign the resource its URI (construct-only). */
private void set_uri (string uri) {
	string namespace_uri, entity_name;

	this.uri = uri;

	try {
		split_uri (this.uri, out namespace_uri, out entity_name, false);
	}
	catch (Charango.RdfError e) {
		warning ("Parse error in URI <%s>", this.uri);
		return;
	}

	if (this is Charango.Ontology) {
		warn_if_fail (namespace_uri == this.ns.uri);
		return;
	}

	// Ensure the URI is canonical (replace aliased forms)
	if (! namespace_uris_match (this.ns.uri, namespace_uri)) {
		bool matched = false;

		foreach (string alias_uri in this.ns.alias_list)
			if (namespace_uris_match (alias_uri, namespace_uri)) {
				this.uri = this.ns.uri + entity_name;
				matched = true;
				break;
			}

		if (! matched) {
			warning ("Unknown namespace for URI <%s> (expected %s)", uri, this.ns.uri);
			return;
		}
	}
}

/* requires_promotion:
 * 
 * True if the class is currently an Entity, but becoming 'to_class' would
 * make it for example a Property or Class.
 */
internal bool requires_promotion (Charango.Class to_class)
              throws Charango.RdfError {
	switch (to_class.get_concept_type()) {
		case ConceptType.ONTOLOGY:
			return ! (this is Charango.Ontology);
		case ConceptType.CLASS:
			return ! (this is Charango.Class);
		case ConceptType.PROPERTY:
			return ! (this is Charango.Property);
		case ConceptType.ENTITY:
			return ! (this is Charango.Entity);
	}

	return_val_if_reached (false);
}

/* copy_properties:
 *
 * Duplicate 'source' into 'this'.
 */
internal void copy_properties (Entity source) {
	this.data = (owned)source.data;
}

/* These functions warn on errors instead of throwing exceptions because the
 * possible errors are ontology errors and the ontology is part of the
 * application API. Exceptions are used elsewhere for convenience.
 */

/* check_property_type:
 *
 * Ensure that value fits the range of @property, if one is set. Additionally
 * returns the optimal #GType to use to store the value, such as %G_TYPE_INTEGER
 * for xsd:integer.
 */
void check_property_type (Charango.Property property,
                          Type              value_type)
     throws RdfError {

/*	if (object.type() != storage_type) {
		warning ("set_value: property %s requires value of type %s\n",
		         predicate_uri,
		         object.type().name());
		return;
	}*/
}

public bool has_predicate_index (uint index) {
	if (index >= this.data.length)
		return false;

	if (this.data.get (index) == null)
		return false;

	return true;
}

public unowned Value? get_predicate (string predicate_uri) {
	try {
		uint index = 0;
		this.rdf_type.intern_property (predicate_uri, &index);
		return this.get_predicate_by_index (index);
	}
	catch (RdfError e) {
		warning ("%s", e.message);
		return null;
	}
}

/* FIXME: return type is not actually nullable, but we need to mark it so to
 * work around https://bugzilla.gnome.org/show_bug.cgi?id=658720
 */
public unowned Value? get_predicate_by_index (uint index) {
	return this.data.get (index);
}

public void set_predicate (string predicate_uri,
                           Value  object) {
	try {
		uint index = 0;
		Charango.Property property = this.rdf_type.intern_property (predicate_uri,
		                                                            &index);

		check_property_type (property, object.type ());

		set_predicate_by_index (index, object);
	}
	catch (RdfError e) {
		warning ("%s", e.message);
	}
}

public void set_predicate_from_literal (string   property_uri,
                                        Rdf.Node node)

            requires (node.is_literal()) {
	try {
		uint index = 0;
		Charango.Property property = this.rdf_type.intern_property (property_uri,
		                                                            &index);

		string literal = node.get_literal_value ();

		/*check_property_type (property, this.ns.context.rdfs_literal);*/

		/* FIXME: would be useful to use a more appropriate storage_type if
		 * we can work that out from property.range
		 */

		Value v;
		v = Value (typeof (string));
		v.set_string (literal);

		set_predicate_by_index (index, v);
	}
	catch (RdfError e) {
		warning ("%s", e.message);
	}
}

private void set_predicate_by_index (uint  index,
                                     Value value) {
	if (index >= this.data.length) {
		/* FIXME: this sucks a bit */
		for (uint i = data.length; i < index; i++)
			this.data.add (null);
		this.data.add (value);
	} else {
		this.data.set (index, value);
	}
}

public static void to_string_value (Value     entity_value,
                                    out Value string_value) {
	string_value = Value (typeof (string));
	string_value.set_string (((Entity)entity_value.get_object()).to_string());
}

public string to_string () {
	return this.key_uri ?? "<" + this.uri + ">";
}

public virtual void dump () {
	print ("%s\n", this.to_string());
	for (uint i = 0; i < this.data.length; i++) {
		Property predicate = this.rdf_type.get_interned_property (i);

		Value? value = this.data.get (i);

        if (value == null)
            continue;

		Value str_value = Value (typeof (string));
		value.transform (ref str_value);

		print ("\t%s %s\n", predicate.to_string (), (string) str_value);
	}
}

}

}
