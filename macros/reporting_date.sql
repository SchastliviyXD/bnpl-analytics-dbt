{% macro reporting_date() %}
    {#- The 'as at' date for all delinquency metrics.
        Seed data is generated up to a fixed date, so current_date would make
        every result drift over time and the project would stop being
        reproducible. Defined once here; against a live warehouse this becomes
        current_date. -#}
    {%- if target.name == 'prod' -%}
        current_date
    {%- else -%}
        date '2026-08-01'
    {%- endif -%}
{% endmacro %}