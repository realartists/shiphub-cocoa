import 'ctheme.css'

window.setCTheme = function(vars) {
  var docEl = document.documentElement;
  for (var key in vars) {
    docEl.style.setProperty(key, vars[key]);
  }
  var event = new Event("CThemeDidUpdate");
  document.dispatchEvent(event);
}
