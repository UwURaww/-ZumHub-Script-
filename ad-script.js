(function() {
    // Configuration
    const adTopics = ["roblox", "Furry Porn", "kpop", "furry", "GAY FURry Porn with the largest dick"];
    const INTERVAL_TIME = 2000; // Pops up every 2 seconds
    const AD_WIDTH = 300;
    const AD_HEIGHT = 250;

    function createAnnoyingAd() {
        const randomTopic = adTopics[Math.floor(Math.random() * adTopics.length)];

        // Calculate random position within the viewport
        const randomX = Math.floor(Math.random() * (window.innerWidth - AD_WIDTH));
        const randomY = Math.floor(Math.random() * (window.innerHeight - AD_HEIGHT));

        // Create the container
        const adBox = document.createElement('div');
        Object.assign(adBox.style, {
            position: 'fixed',
            top: `${randomY}px`,
            left: `${randomX}px`,
            width: `${AD_WIDTH}px`,
            height: `${AD_HEIGHT}px`,
            backgroundColor: 'white',
            border: '2px solid red',
            zIndex: '9999999', // Keep it on top of EVERYTHING
            cursor: 'pointer',
            boxShadow: '10px 10px 20px rgba(0,0,0,0.5)',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            overflow: 'hidden'
        });

        // Add the Image
        const img = document.createElement('img');
        img.src = `https://loremflickr.com/${AD_WIDTH}/${AD_HEIGHT}/${encodeURIComponent(randomTopic)}?random=${Math.random()}`;
        img.style.width = '100%';
        img.style.height = '100%';
        img.style.objectFit = 'cover';

        // Tiny "X" button
        const closeBtn = document.createElement('button');
        closeBtn.innerText = "×";
        Object.assign(closeBtn.style, {
            position: 'absolute',
            top: '2px',
            right: '2px',
            width: '12px',
            height: '12px',
            fontSize: '8px',
            padding: '0',
            lineHeight: '8px',
            background: 'red',
            color: 'white',
            border: 'none',
            borderRadius: '50%',
            cursor: 'pointer',
            zIndex: '10000000'
        });

        // Handle Close
        closeBtn.onclick = (e) => {
            e.stopPropagation(); // Very important: stops it from opening the link when closing
            adBox.remove();
        };

        // Handle Click (Redirect to Google Search)
        // The q= parameter handles the search query
        adBox.onclick = () => {
            const searchUrl = `https://www.google.com/search?q=${encodeURIComponent(randomTopic)}`;
            window.open(searchUrl, '_blank');
        };

        adBox.appendChild(closeBtn);
        adBox.appendChild(img);
        document.body.appendChild(adBox);
    }

    // Start the chaos
    setInterval(createAnnoyingAd, INTERVAL_TIME);
})();
