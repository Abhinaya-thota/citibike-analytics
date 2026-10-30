{#- Small, dependency-free versions of the dbt_utils tests this project needs. -#}

{% test expression_is_true(model, expression, where=None) %}
select * from {{ model }}
where not ({{ expression }})
{% if where %} and {{ where }} {% endif %}
{% endtest %}

{% test accepted_range(model, column_name, min_value=None, max_value=None) %}
select * from {{ model }}
where {{ column_name }} is not null
  and (
    {% if min_value is not none %} {{ column_name }} < {{ min_value }} {% else %} false {% endif %}
    or
    {% if max_value is not none %} {{ column_name }} > {{ max_value }} {% else %} false {% endif %}
  )
{% endtest %}

{% test unique_combination_of_columns(model, combination_of_columns) %}
select {{ combination_of_columns | join(', ') }}, count(*) as n
from {{ model }}
group by all
having count(*) > 1
{% endtest %}
