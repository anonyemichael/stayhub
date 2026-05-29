{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    // Initialize the Flutter engine
    const appRunner = await engineInitializer.initializeEngine();
    
    // Run the app, this waits until the first frame is rendered
    await appRunner.runApp();
    
    // Smoothly hide the HTML splash screen
    const loader = document.getElementById('loading-indicator');
    if (loader) {
      loader.style.transition = 'opacity 0.6s ease-out';
      loader.style.opacity = '0';
      setTimeout(() => loader.style.display = 'none', 600);
    }
  }
});
