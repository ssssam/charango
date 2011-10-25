using Charango;
using Gtk;

extern static const string SRCDIR;

namespace OntologyBrowser {

/* FIXME: should be able to do this with a Charango view :) */
/* Gives a view in the following form:
 *
 *   Ontologies
 *     - Classes
 *         - Properties
 *     - Resources
 *
 * So owl:Ontology > (rdfs:Class > rdfs:Property, rdf:Resource)
 *
 * Iterator format:
 *   user_data = node
 */
[Compact]
public class Node {
	public Charango.Entity? entity;

	public int index;
	public int depth;
	public Node *parent;
	public Node *child;
	public Node *prev;
	public Node *next;

	public Node (Charango.Entity? entity,
	             int              index,
	             int              depth) {
		this.entity = entity;
		this.index = index;
		this.depth = depth;
	}

	public void add_to_tree (Node *parent,
	                         Node *prev) {
		this.parent = parent;
		this.prev = prev;

		if (prev == null)
			parent->child = this;
		else
			prev->next = this;
	}
}

public class ConceptTree: GLib.Object, Gtk.TreeModel {
	Charango.Context context;
	int stamp;

	Node *root;

	Gtk.TreeModelFlags get_flags () {
		return 0;
	}

	int get_n_columns () {
		return 1;
	}

	GLib.Type get_column_type (int index) {
		return typeof(string);
	}

	bool get_iter (out Gtk.TreeIter iter,
	               Gtk.TreePath     path) {
		iter = Gtk.TreeIter ();
		iter.stamp = this.stamp;
		iter.user_data = null;

		Node *node = this.root;
		int[] path_indices = path.get_indices ();
		int d, i;
		for (d=0; d<path.get_depth(); d++) {
			node = node->child;

			if (node == null)
				return false;
			return_val_if_fail (node->depth == d, false);

			for (i=0; i<path_indices[d]; i++) {
				node = node->next;

				if (node == null)
					return false;
			}

			return_val_if_fail (node->index == i, false);
		}

		iter.user_data = node;
		return true;
	}

	Gtk.TreePath? get_path (Gtk.TreeIter iter) {
		return_val_if_fail (iter.stamp == this.stamp, false);
		return_val_if_fail (iter.user_data != null, false);

		Node *node = (Node *)iter.user_data;
		Gtk.TreePath path = new Gtk.TreePath ();

		for (int d=node->depth; d>=0; d--) {
			path.prepend_index (node->index);
			node = node->parent;
		}

		return path;
	}

	void get_value (Gtk.TreeIter   iter,
	                int            column,
	                out GLib.Value value) {
		return_if_fail (iter.stamp == this.stamp);
		return_if_fail (iter.user_data != null);

		Node *node = iter.user_data;
		Charango.Entity e = node->entity;

		return_if_fail (e != null);

		value = Value (typeof (string));
		value.set_string (e.uri);
	}

	bool iter_next (ref Gtk.TreeIter iter) {
		return_val_if_fail (iter.stamp == this.stamp, false);
		return_val_if_fail (iter.user_data != null, false);

		Node *node = iter.user_data;

		if (node->next == null)
			return false;

		iter.user_data = node->next;
		return true;
	}

	bool iter_previous (ref Gtk.TreeIter iter) {
		return_val_if_fail (iter.stamp == this.stamp, false);
		return_val_if_fail (iter.user_data != null, false);

		Node *node = iter.user_data;

		if (node->prev == null)
			return false;

		iter.user_data = node->prev;
		return true;
	}

	bool iter_children (out Gtk.TreeIter iter,
	                    Gtk.TreeIter?    parent) {
		Node *node;
		iter = Gtk.TreeIter ();

		if (parent == null)
			node = this.root;
		else {
			return_val_if_fail (parent.stamp == this.stamp, false);
			return_val_if_fail (parent.user_data != null, false);

			node = parent.user_data;
		}

		if (node->child == null)
			return false;

		iter.stamp = this.stamp;
		iter.user_data = node->child;
		return true;
	}

	bool iter_has_child (Gtk.TreeIter iter) {
		return_val_if_fail (iter.stamp == this.stamp, false);
		return_val_if_fail (iter.user_data != null, false);

		Node *node = iter.user_data;

		return (node->child != null);
	}

	int iter_n_children (Gtk.TreeIter? iter) {
		Node *node;

		if (iter == null)
			node = this.root;
		else {
			return_val_if_fail (iter.stamp == this.stamp, false);
			return_val_if_fail (iter.user_data != null, false);

			node = iter.user_data;
		}

		int n = 0;

		if (node->child == null)
			return n;

		node = node->child;
		while (node->next != null)
			node = node->next;

		return node->index + 1;
	}

	bool iter_nth_child (out Gtk.TreeIter iter,
	                     Gtk.TreeIter?    parent,
	                     int              n) {
		Node *node;
		iter = Gtk.TreeIter ();

		if (parent == null)
			node = this.root;
		else {
			return_val_if_fail (parent.stamp == this.stamp, false);
			return_val_if_fail (parent.user_data != null, false);

			node = parent.user_data;
		}

		if (node->child == null)
			return false;

		node = node->child;
		while (node->next != null)
			node = node->next;

		iter.stamp = this.stamp;
		iter.user_data = node;
		return true;
	}

	bool iter_parent (out Gtk.TreeIter iter,
	                  Gtk.TreeIter     child) {
		return_val_if_fail (child.stamp == this.stamp, false);
		return_val_if_fail (child.user_data != null, false);

		Node *node = child.user_data;
		iter = Gtk.TreeIter ();

		if (node->parent == this.root)
			return false;

		iter.stamp = this.stamp;
		iter.user_data = node->parent;
		return true;
	}

	void ref_node (Gtk.TreeIter iter) {
	}

	void unref_node (Gtk.TreeIter iter) {
	}

	private static int compare_namespaces_by_uri (Charango.Namespace a,
	                                              Charango.Namespace b) {
		return strcmp (a.uri, b.uri);
	}

	private static int compare_entities_by_uri (Charango.Entity a,
	                                            Charango.Entity b) {
		return strcmp (a.uri, b.uri);
	}

	public ConceptTree (Charango.Context context) {
		this.context = context;
		this.stamp = (int) Random.next_int ();

		var namespace_list = context.get_namespace_list();
		namespace_list.sort ((GLib.CompareFunc<Charango.Namespace>)compare_namespaces_by_uri);

		this.root = new Node (null, 0, -1);

		/* FIXME: we shouldn't be using these ontology-specific API's, and
		 * they shouldn't exist - Context should implement Charango.Source
		 */

		int i = 0;
		Node *ns_prev = null;
		foreach (Namespace ns in namespace_list) {
			if (ns.ontology == null)
				continue;

			Node *ns_node = new Node (ns.ontology, i ++, 0);
			ns_node->add_to_tree (this.root, ns_prev);
			ns_prev = ns_node;

			var class_list = ns.get_class_list ();
			class_list.sort ((GLib.CompareFunc<Charango.Class>)compare_entities_by_uri);

			int j = 0;
			Node *x_prev = null;
			foreach (Class x in class_list) {
				Node *x_node = new Node (x, j ++, 1);
				x_node->add_to_tree (ns_node, x_prev);
				x_prev = x_node;
			}

			var property_list = ns.get_property_list ();
			property_list.sort ((GLib.CompareFunc<Charango.Property>)compare_entities_by_uri);

			foreach (Property x in property_list) {
				Node *x_node = new Node (x, j ++, 1);
				x_node->add_to_tree (ns_node, x_prev);
				x_prev = x_node;
			}

			var entity_list = ns.get_entity_list ();
			entity_list.sort (compare_entities_by_uri);

			foreach (Entity x in entity_list) {
				Node *x_node = new Node (x, j ++, 1);
				x_node->add_to_tree (ns_node, x_prev);
				x_prev = x_node;
			}
		}
	}

	~ConceptTree () {
		Node *node = this.root;

		while (node->child != null)
			node = node->child;

		while (node->parent != null) {
			while (node->next != null) {
				node = node->next;
				delete node->prev;
			}

			Node *parent = node->parent;
			delete node;
			node = parent;
		}

		return_if_fail (node == this.root);
		delete this.root;
	}
}


/* PropertyList:
 * A GtkTreeModel listing the properties of a specific entity.
 * 
 * This is complicated slightly by the fact that predicates are indexed on the
 * whole class, but not all of them may have values on the specific resource.
 * We store the absolute index in the iterator and iter_next() fast-forwards
 * through any that are not set for this resource.
 *
 * Iterator format:
 *  - user_data: property index
 */
public class PropertyList: GLib.Object, Gtk.TreeModel {
	public Charango.Entity subject;

	Charango.Context context;
	int stamp;

	uint n_predicates;
	uint max_index;

	Gtk.TreeModelFlags get_flags () {
		return 0;
	}

	int get_n_columns () {
		return 2;
	}

	GLib.Type get_column_type (int index) {
		return typeof(string);
	}

	bool get_iter (out Gtk.TreeIter iter,
	               Gtk.TreePath     path) {
		return_val_if_fail (path.get_depth() == 1, false);

		int index = path.get_indices()[0];
		iter = Gtk.TreeIter ();

		return this.iter_nth_child (out iter, null, index);
	}

	Gtk.TreePath? get_path (Gtk.TreeIter iter) {
		return_val_if_fail (iter.stamp == this.stamp, false);

		int index;
		Gtk.TreeIter probe_iter = iter;
		for (index = 0; this.iter_previous (ref probe_iter); );

		Gtk.TreePath path = new Gtk.TreePath ();
		path.append_index ((int) index);

		return path;
	}

	void get_value (Gtk.TreeIter   iter,
	                int            column,
	                out GLib.Value value) {
		return_if_fail (iter.stamp == this.stamp);

		int index = (int)iter.user_data;
		value = Value (typeof (string));

		if (column == 0) {
			// Property name
			Charango.Property property = this.subject.rdf_type.get_interned_property (index);
			value.set_string (property.uri);
		}

		if (column == 1) {
			Value? predicate_value = this.subject.get_predicate_by_index (index);
			if (predicate_value != null)
				predicate_value.transform (ref value);
		}
	}

	bool iter_next (ref Gtk.TreeIter iter) {
		return_val_if_fail (iter.stamp == this.stamp, false);

		int index = (int) iter.user_data ;
		while (! this.subject.has_predicate_index (++ index)) {
			if (index >= this.max_index)
				return false;
		};

		iter.user_data = (void *)index;
		return true;
	}

	bool iter_previous (ref Gtk.TreeIter iter) {
		return_val_if_fail (iter.stamp == this.stamp, false);

		int index = (int) iter.user_data;
		while (! this.subject.has_predicate_index (-- index)) {
			if (index < 0)
				return false;
		};

		iter.user_data = (void *)index;
		return true;
	}

	bool iter_children (out Gtk.TreeIter iter,
	                    Gtk.TreeIter?    parent) {
		iter = Gtk.TreeIter ();

		if (parent == null && this.n_predicates > 0) {
			iter.stamp = this.stamp;
			iter.user_data = (void *)0;
			return true;
		}

		return false;
	}

	bool iter_has_child (Gtk.TreeIter iter) {
		return false;
	}

	int iter_n_children (Gtk.TreeIter? iter) {
		if (iter == null)
			return (int)this.n_predicates;

		return_val_if_fail (iter.stamp == this.stamp, 0);

		return 0;
	}

	bool iter_nth_child (out Gtk.TreeIter iter,
	                     Gtk.TreeIter?    parent,
	                     int              n) {
		this.iter_children (out iter, parent);

		for (int i = 0; i < n; i ++) {
			bool valid = this.iter_next (ref iter);

			if (! valid)
				return false;
		}

		return true;
	}

	bool iter_parent (out Gtk.TreeIter iter,
	                  Gtk.TreeIter     child) {
		iter = Gtk.TreeIter ();
		return false;
	}

	void ref_node (Gtk.TreeIter iter) {
	}

	void unref_node (Gtk.TreeIter iter) {
	}

	public PropertyList (Charango.Context context,
	                     Charango.Entity  subject) {
		this.context = context;
		this.stamp = (int) Random.next_int ();

		this.subject = subject;
		this.max_index = subject.rdf_type.get_n_interned_properties ();

		this.n_predicates = 0; 
		for (int i = 0; i < this.max_index; i ++) {
			if (this.subject.has_predicate_index (i))
				this.n_predicates ++;
		}
	}
}


public class MainWindow: Gtk.Window {
	Charango.Context context;

	Gtk.TreeView properties_tree_view;

	void build_ui () {
		var concepts = new Gtk.TreeView ();
		concepts.insert_column_with_attributes (-1, 
		                                        "Concept", 
		                                        new Gtk.CellRendererText (),
		                                        "text", 0);
		concepts.set_headers_visible (false);
		concepts.set_model (new ConceptTree (this.context));

		var concepts_scrolled_window = new Gtk.ScrolledWindow (null, null);
		concepts_scrolled_window.set_shadow_type (Gtk.ShadowType.IN);
		concepts_scrolled_window.set_size_request (200, 500);
		concepts_scrolled_window.expand = true;
		concepts_scrolled_window.margin = 4;
		concepts_scrolled_window.add (concepts);

		var properties = new Gtk.TreeView ();
		properties.set_headers_visible (false);
		properties.insert_column_with_attributes (-1,
		                                          "Property",
		                                          new Gtk.CellRendererText (),
		                                          "text", 0);
		properties.insert_column_with_attributes (-1,
		                                          "Value",
		                                          new Gtk.CellRendererText (),
		                                          "text", 1);

		var properties_scrolled_window = new Gtk.ScrolledWindow (null, null);
		properties_scrolled_window.set_shadow_type (Gtk.ShadowType.IN);
		properties_scrolled_window.set_size_request (400, 500);
		properties_scrolled_window.expand = true;
		properties_scrolled_window.margin = 4;
		properties_scrolled_window.add (properties);

		var paned = new Gtk.Paned (Orientation.HORIZONTAL);
		paned.add1 (concepts_scrolled_window);
		paned.add2 (properties_scrolled_window);

		this.properties_tree_view = properties;

		var concepts_selection = concepts.get_selection ();
		concepts_selection.changed.connect ((selection) => {
			Gtk.TreeModel concepts_model;
			Gtk.TreeIter concepts_row;
			PropertyList properties_model = (PropertyList)this.properties_tree_view.get_model ();

			bool has_selection = selection.get_selected (out concepts_model, out concepts_row);

			if (! has_selection) {
				this.properties_tree_view.set_model (null);
				return;
			}

			Value selected_concept_uri;
			concepts_model.get_value (concepts_row, 0, out selected_concept_uri);

			if (properties_model != null && properties_model.subject.uri == selected_concept_uri.get_string ())
				return;

			Entity selected_concept = this.context.find_entity (selected_concept_uri.get_string ());
			properties_model = new PropertyList (this.context, selected_concept);
			this.properties_tree_view.set_model (properties_model);
		});

		this.add (paned);
		paned.show_all ();
	}

	public MainWindow (Charango.Context context) {
		this.context = context;

		this.title = "Charango Ontology Browser";
		this.set_position (WindowPosition.CENTER);

		this.build_ui ();

		this.destroy.connect (Gtk.main_quit);
	}
}

int main (string[] args) {
	Gtk.init (ref args);

	var path = Path.build_filename (SRCDIR, "charango", "data", "ontologies", null);

	List<Warning> warning_list = null;
	var context = new Charango.Context ();
	try {
		context.add_local_ontology_source (path);

		var namespace_list = context.get_namespace_list ();
		foreach (Namespace ns in namespace_list) {
			context.load_namespace (ns.uri, out warning_list);
		}
	}
	  catch (FileError error) {
		print ("Unable to find ontologies: %s\n", error.message);
		return 1;
	  }
	  catch (RdfError error) {
		print ("Error loading namespace: %s\n", error.message);
		return 3;
	  }

	if (warning_list != null)
		print ("[%u warnings]\n", warning_list.length());

	/*foreach (unowned Warning w in warning_list)
		print ("\t%s\n", w.message);*/

	var app_window = new MainWindow(context);
	app_window.show ();

	Gtk.main ();

	return 0;
}

}
