var loadFromIntent = function(){
  var image = new Image();
  image.onLoad = imageLoaded;

  if(window.webkitIntent.data instanceof Blob){
    image.src = window.webkitURL.createObjectURL(window.webkitIntent.data);
  }else{
    image.src = window.webkitIntent.data;
  }
};

var saveIntent = function() {
  var dataURL = document.getElementById('canvas').toDataURL('image/jpeg');
  console.log('returning...' + dataURL);

  if(window.webkitIntent){
    window.webkitIntent.postResult(dataURL);
  }
};

var EditServiceLoaded = function() {
  $('#save').click(saveIntent);
  $('#apply').click(applyFilter);
  $('#undo').click(undo);
  $('#filter').change(filterChange);

  $('#save').attr("disabled", true);
  $('#filter').attr("disabled", true);
  $('#apply').attr("disabled", true);

  var ctx = document.getElementById('canvas').getContext('2d');
  Filters.context = ctx;

  if(window.webkitIntent){
    loadFromIntent();
  }
};

window.addEventListener("load", EditServiceLoaded);
