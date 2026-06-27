(function initAd() {
    // 1. Define your topics
    const adTopics = ["game", "roblox", "kpop", "anime", "furry porn", "gay furry porn ads", "diaper porn ads"];
    const randomTopic = adTopics[Math.floor(Math.random() * adTopics.length)];

    // 2. Create the ad container
    const adContainer = document.createElement('div');
    Object.assign(adContainer.style, {
        width: '300px',
        height: '250px',
        border: '1px solid #ccc',
        cursor: 'pointer',
        overflow: 'hidden',
        margin: '10px'
    });

    // 3. Use a free image service (LoremFlickr)
    // This fetches a random image based on your topic keyword
    const img = document.createElement('img');
    img.src = `https://loremflickr.com/300/250/${encodeURIComponent(randomTopic)}?random=${Math.random()}`;
    Object.assign(img.style, {
        width: '100%',
        height: '100%',
        objectFit: 'cover'
    });

    // 4. Click action
    adContainer.onclick = function() {
        window.open(`https://www.google.com/search?q=${encodeURIComponent(randomTopic)}`, '_blank');
    };

    // 5. Inject into the page
    adContainer.appendChild(img);
    window.addEventListener('DOMContentLoaded', () => {
        const target = document.getElementById('ad-space') || document.body;
        target.appendChild(adContainer);
    });
})();
