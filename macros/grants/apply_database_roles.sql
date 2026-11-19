{% macro apply_database_roles(database_roles) %}
    {# Orchestrates full database role setup from a single declarative payload: creates each database role,
       revokes anything explicitly marked for removal, applies inherited (current + future) privilege
       grants, and maps each role to the account roles and/or applications configured for the current
       target. Delegates to the existing per-step macros -- create_database_role,
       revoke_database_role_inherited_privileges, revoke_database_role_object,
       grant_database_role_inherited_privileges, grant_database_role_to_role, and
       grant_database_role_to_application. (SCHEMA-type privileges are granted/revoked directly rather
       than via INHERITED -- a schema can't contain other schemas -- but that routing lives entirely
       inside grant_database_role_inherited_privileges/revoke_database_role_inherited_privileges now, not
       here, so it's handled consistently for every scoping mode.)

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
       diff-and-revoke isn't feasible to build reliably. Revokes run before grants for each role (not
       guaranteed globally across roles in the payload, but roles are independent of each other so this
       doesn't matter), which is safe since REVOKE on a grant that doesn't exist is a no-op in Snowflake.

       Each `revoke_inherited` entry's `include_schemas`/`exclude_schemas` is completely independent of
       the role's own top-level `include_schemas`/`exclude_schemas` -- it is NOT inherited/merged from the
       role's grant scope. Omitting both on an entry scopes that revoke to the whole database. This is
       deliberate: the main use case for `revoke_inherited` is cleaning up a role's *previous*, typically
       broader, scope as part of narrowing it (e.g. a role used to have whole-database `SELECT`, now
       narrowed to one schema) -- the revoke needs to target the OLD (often whole-database) scope, not
       the role's new, narrower `include_schemas`.

       IMPORTANT Snowflake limitation (not specific to this macro): inherited grants provide no
       object-level exceptions. If an `inherited` entry already covers an object via a container-level
       GRANT INHERITED, a `revoke_objects` entry for that same object/privilege will NOT remove access --
       the inherited grant still applies. `revoke_objects` only removes a *direct* (non-inherited) grant;
       it cannot carve an exception out of a broader inherited grant. #}
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

    {# 2. for each role: revoke anything explicitly marked for removal, then apply inherited grants and
       account role / application mapping. Revoke-before-grant per role is enough -- roles don't depend
       on each other, so there's no need to revoke every role before granting any of them. #}
    {% for db_role, cfg in database_roles.items() %}
        {% for r in cfg.get('revoke_inherited', []) %}
            {% do dbt_dataengineers_utils.revoke_database_role_inherited_privileges(
                r.object_type, r.permissions, [db_role],
                include_schemas=r.get('include_schemas'), exclude_schemas=r.get('exclude_schemas')
            ) %}
        {% endfor %}
        {% for r in cfg.get('revoke_objects', []) %}
            {% do dbt_dataengineers_utils.revoke_database_role_object(r.object_type, r.objects, r.grant_types, [db_role]) %}
        {% endfor %}

        {% set include_schemas = cfg.get('include_schemas') %}
        {% set exclude_schemas = cfg.get('exclude_schemas') %}
        {% for g in cfg.get('inherited', []) %}
            {% do dbt_dataengineers_utils.grant_database_role_inherited_privileges(g.object_type, g.permissions, [db_role], include_schemas=include_schemas, exclude_schemas=exclude_schemas) %}
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
