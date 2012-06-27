var Slide = function(container) {
  var page = location.hash.replace(/#([0-9]*)$/, '$1');
  if (!page) {
    location.hash = '#0';
  }
  this.container = container;
  this.articles = this.container.querySelectorAll('#container > article');

  window.addEventListener('popstate', this.transition.bind(this));
  window.addEventListener('keydown', (function(e) {
    var page = parseInt(location.hash.replace(/#([0-9]*)$/, '$1'));
    if (e.keyCode == 39) {
      location.hash = page+1 < this.articles.length ? page+1 : this.articles.length-1;
      e.stopPropagation();
      e.preventDefault();
    } else if (e.keyCode == 37) {
      location.hash = page-1 >= 0 ? page-1 : 0;
      e.stopPropagation();
      e.preventDefault();
    }
  }).bind(this));
  this.transition();
}
Slide.prototype = {
  transition: function() {
    var page = parseInt(location.hash.replace(/#([0-9]*)$/, '$1'));
    if (page == NaN) return;
    var position = page / this.articles.length;
    document.body.style.backgroundPositionX = '-'+((parseInt(getComputedStyle(document.body).width) * position) | 0)+'px';
    var first = page-3 > 0 ? page-3 : 0;
    var last = page+4 < this.articles.length ? page+4 : this.articles.length;
    for (var i = first; i < last; i++) {
      if (i == page-2)      this.articles[i].className = 'prev2';
      else if (i == page-1) this.articles[i].className = 'prev';
      else if (i == page)   this.articles[i].className = 'current';
      else if (i == page+1) this.articles[i].className = 'next';
      else if (i == page+2) this.articles[i].className = 'next2';
      else this.articles[i].className = '';
    }
  }
}