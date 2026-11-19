{% macro apply_database_roles(database_roles) %}
    {# Orchestrates full database role setup from a single declarative payload: creates each database role,
       revokes anything explicitly marked for removal, applies inherited (current + future) privilege
       grants, and maps each role to the account roles and/or applications configured for the current
       target. Delegates to the existing per-step macros -- create_database_role,
       revoke_database_role_inherited_privileges, revoke_database_role_object,
       grant_database_role_schema_privileges, grant_database_role_inherited_privileges,
       grant_database_role_to_role, and grant_database_role_to_application.

       Expected shape of `database_roles` (keyed by database role name):
         {
           'DB_ROLE_NAME': {
             'comment': '<string>',
             'inherited': [ { 'object_type': '<TYPE>', 'permissions': ['<PRIV>', ...] }, ... ],
             'include_schemas': ['<SCHEMA>', ...] | none,
             'exclude_schemas': ['<SCHEMA>', ...] | none,       # ignored if include_schemas is set
             'roles': { '<target_name>': ['<ACCOUNT_ROLE>', ...] },        # optional
             'applications': { '<target_name>': ['<APPLICATION>', ...] }, # optional
             'revoke_inherited': [                                        # optional, explicit only --
               { 'object_type': '<TYPE>', 'permissions': ['<PRIV>', ...],  # see note below
                 'include_schemas': [...] | none, 'exclude_schemas': [...] | none }, ...
             ],
             'revoke_objects': [                                          # optional, explicit only
               { 'object_type': '<TYPE>', 'objects': ['<SCHEMA.OBJECT>', ...], 'grant_types': ['<PRIV>', ...] }, ...
             ]
           },
           ...
         }

       `revoke_inherited`/`revoke_objects` are NOT automatic reconciliation (i.e. this macro never
       inspects a role's current grants and revokes anything not declared in `inherited`/`roles`/
       `applications`) -- you must explicitly list what to revoke. This is intentional: Snowflake has no
       reliable way to pre-check a database role's existing inherited grants (no SHOW INHERITED GRANTS /
       no IS_INHERITED column on SHOW GRANTS TO DATABASE ROLE on all account versions), so automatic
       diff-and-revoke isn't feasible to build reliably. Revokes run before grants each invocation, which
       is safe since REVOKE on a grant that doesn't exist is a no-op in Snowflake. #}
    {% if flags.WHICH not in ['run', 'build', 'run-operation'] %}
        {% do log('Skipping apply_database_roles: not run/build/run-operation context', info=True) %}
        {% do return(none) %}
    {% endif %}

    {% if not database_roles %}
        {% do log('apply_database_roles: no database_roles supplied', info=True) %}
        {% do return(none) %}
    {% endif %}

    {# 1. create every database role first -- the grants below assume the role already exists. #}
    {% for db_role, cfg in database_roles.items() %}
        {% do dbt_dataengineers_utils.create_database_role([db_role], cfg.get('comment')) %}
    {% endfor %}

    {# 2. revoke anything explicitly marked for removal -- runs before the grants below so a role being
       narrowed (e.g. from whole-database to a single schema) doesn't momentarily hold both the old and
       new scope for longer than necessary. #}
    {% for db_role, cfg in database_roles.items() %}
        {% for r in cfg.get('revoke_inherited', []) %}
            {% do dbt_dataengineers_utils.revoke_database_role_inherited_privileges(r.object_type, r.permissions, [db_role], include_schemas=r.get('include_schemas'), exclude_schemas=r.get('exclude_schemas')) %}
        {% endfor %}
        {% for r in cfg.get('revoke_objects', []) %}
            {% do dbt_dataengineers_utils.revoke_database_role_object(r.object_type, r.objects, r.grant_types, [db_role]) %}
        {% endfor %}
    {% endfor %}

    {# 3. apply inherited grants + account role / application mapping for every database role. #}
    {% for db_role, cfg in database_roles.items() %}
        {% set include_schemas = cfg.get('include_schemas') %}
        {% set exclude_schemas = cfg.get('exclude_schemas') %}
        {% for g in cfg.get('inherited', []) %}
            {% if g.object_type == 'SCHEMA' and include_schemas %}
                {# a named schema's own USAGE/MONITOR grant isn't an inherited/future concept -- a schema
                   can't contain other schemas, so "ON ALL SCHEMAS IN SCHEMA <name>" is nonsensical. Use
                   the direct schema-privilege grant instead. #}
                {% do dbt_dataengineers_utils.grant_database_role_schema_privileges(g.permissions, include_schemas, [db_role]) %}
            {% else %}
                {% do dbt_dataengineers_utils.grant_database_role_inherited_privileges(g.object_type, g.permissions, [db_role], include_schemas=include_schemas, exclude_schemas=exclude_schemas) %}
            {% endif %}
        {% endfor %}

        {% set account_roles = cfg.get('roles', {}).get(target.name, []) %}
        {% if account_roles %}
            {% do dbt_dataengineers_utils.grant_database_role_to_role(db_role, account_roles) %}
        {% endif %}

        {# database roles can be granted to an application directly (not via an account role) #}
        {% set applications = cfg.get('applications', {}).get(target.name, []) %}
        {% if applications %}
            {% do dbt_dataengineers_utils.grant_database_role_to_application(db_role, applications) %}
        {% endif %}
    {% endfor %}

    {% do log('apply_database_roles: completed for ' ~ (database_roles | length) ~ ' database role(s)', info=True) %}
{% endmacro %}
