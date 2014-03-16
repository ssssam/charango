/* sparql-find-root-pattern
 * Copyright (C) 2014  Sam Thursfield
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, either version 2 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/* You want to:
 *   - parse the graph pattern
 *   - find which is the root term
 *   - this involves actually partially solving the query!
 *
 * RASQAL is handy for parsing (modulo some incompatibilities with Tracker) but
 * doesn't seem to let you get at the internal query algebra (not that I would
 * understand it anyway). Ultimately you just need to take all the variables in
 * a graph and then find the root node of that graph. There are clever ways to
 * do that I'm sure but brute force would work for now.
 *
 * To be smarter, filter the graph against the list of variables in the SELECT(),
 * and warn if there are unused terms in the query.
 *
 * If there's no root node, the query has no results so it doesn't matter.
 *
 * What you actually want to do is not identify one term, but to remove all of
 * the terms that depend on other terms to make the simplest solvable query.
 * You can do that I'm sure!
 */

#include <rasqal.h>

#include <assert.h>
#include <stdio.h>

/* UGH */
#define MAX_QUERY 6666

void print_graph_patterns(rasqal_query *query)
{
	rasqal_graph_pattern *pattern = rasqal_query_get_query_graph_pattern(query);
	rasqal_graph_pattern_print(pattern, stdout);
};

void add_dependent (rasqal_variable *variable,
                    rasqal_graph_pattern *pattern)
{
	if (variable->user_data == NULL) {
		variable->user_data = raptor_new_sequence(NULL, rasqal_graph_pattern_print);
	}

	raptor_sequence_push(variable->user_data, pattern);
}

/* Fill the user_data field of each raptor_variable with the set of patterns
 * that include this variable.
 */
int collect_dependency_graph(rasqal_query *query,
                             rasqal_graph_pattern *graph_pattern,
                             void *user_data)
{
	rasqal_triple *triple;
	rasqal_variable *variable;
	rasqal_variables_table *vars_table = user_data;
	int i;

	i = 0;
	while (1) {
		triple = rasqal_graph_pattern_get_triple(graph_pattern, i);

		if (triple == NULL)
			break;

		printf ("\nPattern %i: ", i);
		rasqal_triple_print(triple, stdout);

		variable = rasqal_literal_as_variable(triple->subject);
		if (variable != NULL)
			add_dependent(variable, graph_pattern);

		variable = rasqal_literal_as_variable(triple->predicate);
		if (variable != NULL)
			add_dependent(variable, graph_pattern);

		variable = rasqal_literal_as_variable(triple->object);
		if (variable != NULL)
			add_dependent(variable, graph_pattern);

		i ++;
	}
	return 0;
}

void find_root_pattern(rasqal_world *world,
                       const char *text,
                       raptor_iostream *output)
{
	rasqal_query *query;
	rasqal_query *root_query;
	rasqal_variable *var;
	raptor_sequence *patterns;
	raptor_sequence *all_vars;
	int i;

	query = rasqal_new_query(world, "sparql11", NULL);
	rasqal_query_prepare(query, text, NULL);

	/* Root query is prepared by removing the terms we don't want
	 * from the original. There seems to be no copy() method.
	 */
	root_query = rasqal_new_query(world, "sparql11", NULL);
	rasqal_query_prepare(root_query, text, NULL);

	var = rasqal_query_get_variable(query, 0);
	if (var == NULL) {
		/* No variables, so no way of usefully simplifying the query. Is this
		 * possible in normal usage? */
		return;
	}

	rasqal_query_graph_pattern_visit2 (query, collect_dependency_graph, var->vars_table);

	all_vars = rasqal_query_get_all_variable_sequence (query);
	for (i = 0; i < raptor_sequence_size(all_vars); i++) {
		var = raptor_sequence_get_at(all_vars, i);
		if (var->user_data == NULL) {
			printf ("Variable: %s, no dependents\n", var->name);
		} else {
			printf ("Variable: %s, dependents: %i\n", var->name,
			        raptor_sequence_size(var->user_data));
		}
	}

	rasqal_query_write(output, root_query, NULL, NULL);
}

int main()
{
	rasqal_world *world = rasqal_new_world();
	char text[MAX_QUERY];
	raptor_iostream *result_iostream;
	char *result;

	fread(text, 1, MAX_QUERY-1, stdin);

	//print_graph_patterns(query);
	result_iostream = raptor_new_iostream_to_string(
	        //rasqal_world_get_raptor(world),
			raptor_new_world(),
	        (void **)&result, NULL, NULL);
	assert (result_iostream != NULL);

	//results = rasqal_query_execute(query);
	find_root_pattern(world, text, result_iostream);
	raptor_iostream_write_end(result_iostream);
	raptor_free_iostream(result_iostream);
	printf ("Result: %s\n", result);

	rasqal_free_world(world);
	return 0;
}
