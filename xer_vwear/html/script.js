// script.js (modified for decimal mileage with comma, trim trailing zeros)

let visible = false;

window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.action === "showUI") {
        document.getElementById("container").style.display = "block";
        visible = true;
    } else if (data.action === "hideUI") {
        document.getElementById("container").style.opacity = 0;  // Fade out
        setTimeout(() => {
            document.getElementById("container").style.display = "none";
            document.getElementById("container").style.opacity = 1;
        }, 400);
        visible = false;
    } else if (data.action === "update" && data.data) {
        updateUI(data.data);
    }
});

function updateUI(d) {
    document.getElementById("plate").textContent = d.plate || "UNKNOWN";
    
    // Format mileage with 1 decimal and comma as separator, trim trailing ,0
    let mileage = d.mileage || 0;
    let formattedMileage = mileage.toFixed(1).replace('.', ',').replace(',0$', '');
    document.getElementById("mileage").textContent = formattedMileage;

    setPart("engine", 100 - (d.wear_engine || 0));
    setPart("transmission", 100 - (d.wear_transmission || 0));
    setPart("brakes", 100 - (d.wear_brakes || 0));
    setPart("suspension", 100 - (d.wear_suspension || 0));
    setPart("tires", d.wear_tires || 100);
}

function setPart(part, value) {
    const fill = document.getElementById(part + "-fill");
    const percent = document.getElementById(part);
    
    fill.style.width = value + "%";
    percent.textContent = Math.floor(value) + "%";  // Still floor for display, but data is decimal

    if (value > 70) fill.style.background = "#00ff00";
    else if (value > 40) fill.style.background = "#ffaa00";
    else fill.style.background = "#ff0066";
}

// ESC TO CLOSE — FIXED VERSION
document.addEventListener('keyup', function(e) {
    if (e.key === "Escape" && visible) {
        visible = false;
        document.getElementById("container").style.display = "none";

        fetch(`https://${GetParentResourceName()}/closeUI`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    }
});