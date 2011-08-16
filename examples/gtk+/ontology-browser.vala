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

	Gtk.TreePath get_path (Gtk.TreeIter iter) {
		return_val_if_fail (iter.stamp == this.stamp, false);
		return_val_if_fail (iter.user_data != null, false);

		Node *node = (Node *)iter.user_data;
		Gtk.TreePath path = new Gtk.TreePath ();

		for (int d=node->depth-1; d>=0; d--) {
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

		value.init (typeof (string));
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
		return_val_if_fail (iter.stamp == this.stamp, false);
		return_val_if_fail (iter.user_data != null, false);

		Node *node = iter.user_data;
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

public class MainWindow: Gtk.Window {
	Charango.Context context;

	void build_ui () {
		var concepts = new Gtk.TreeView ();
		concepts.set_model (new ConceptTree (this.context));
		concepts.insert_column_with_attributes (-1, 
		                                        "Concept", 
		                                        new Gtk.CellRendererText (),
		                                        "text", 0);

		var concepts_scrolled_window = new Gtk.ScrolledWindow (null, null);
		concepts_scrolled_window.set_size_request (150, 350);
		concepts_scrolled_window.expand = true;
		concepts_scrolled_window.margin = 4;
		concepts_scrolled_window.add (concepts);

		var grid = new Gtk.Grid ();
		grid.attach (concepts_scrolled_window, 0, 0, 1, 1);

		this.add (grid);
		grid.show_all ();

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

	var context = new Charango.Context ();
	List<Warning> warning_list;
	try {
		context.add_local_ontology_source (path);
		// These two pull in every available ontology.
		// FIXME: would be cool if we could do the loading incrementally based
		// on what the user clicks on :)
		context.load_namespace ("http://purl.org/ontology/mo/", out warning_list);
		context.load_namespace ("http://creativecommons.org/ns#", null);
	}
	  catch (FileError error) {
		print ("Unable to find ontologies: %s\n", error.message);
		return 1;
	  }
	  catch (ParseError error) {
		print ("Error loading ontology data: %s\n", error.message);
		return 2;
	  }
	  catch (OntologyError error) {
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
