$(document).ready(function() {
  $('#dependencies').multiselect({
    columns: 1,
    placeholder: "Select dependencies",
    search: true
  });
});

function append_activity(table_id)
{
  var del_button = '<button type="button" onClick="delete_activity(this)">Del</button>';
  var table_body = document.getElementById(table_id);
  var row = table_body.insertRow(-1);

  var cell_id = row.insertCell(-1);
  var cell_act = row.insertCell(-1);
  var cell_dep = row.insertCell(-1);
  var cell_min = row.insertCell(-1);
  var cell_max = row.insertCell(-1);
  var cell_del = row.insertCell(-1);

  // Every field is editable on click except for the ID field.

  // Assign a random number to ID
  id = 000000;
  cell_id.setAttribute("name", "id");
  cell_id.innerHTML = id;

  cell_dep.setAttribute("name", "dependencies");

  cell_act.innerHTML = document.activities.activity.value;
  cell_act.setAttribute("name", "activity");

  cell_min.setAttribute("name", "min");
  cell_min.setAttribute("class", "number");
  cell_min.innerHTML = document.activities.min.value;

  cell_max.setAttribute("name", "max");
  cell_max.setAttribute("class", "number");
  cell_max.innerHTML = document.activities.max.value;

  cell_del.innerHTML = del_button;

  // Append the activity to options in the input form
  var elem = document.createElement('option');
  elem.setAttribute("value", id);
  var text = document.createTextNode(document.activities.activity.value);
  document.activities.dependencies.appendChild(elem);
  elem.appendChild(text);
}

function delete_activity(obj)
{
  var tr = obj.parentNode.parentNode;
  tr.parentNode.deleteRow(tr.sectionRowIndex);
}

function cancel()
{
}

function sort_activity()
{
}
