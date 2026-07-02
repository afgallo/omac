// Mount an asciinema player into any <div data-cast="…"> on the page.
function omacMountCasts() {
  document.querySelectorAll("[data-cast]").forEach(function (el) {
    if (el.dataset.mounted) return;
    el.dataset.mounted = "1";
    AsciinemaPlayer.create(el.dataset.cast, el, {
      autoPlay: true, loop: true, idleTimeLimit: 2, poster: "npt:0:2", fit: "width"
    });
  });
}
document.addEventListener("DOMContentLoaded", omacMountCasts);
document.addEventListener("DOMContentSwitch", omacMountCasts); // navigation.instant
