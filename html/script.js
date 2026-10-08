// ==========================================
// qbx_pthud | Unified Script.js
// Player HUD + Car HUD + Minimap + Compass
// Author: Mirage
// ==========================================

let lastEngineHealth = 1000;
let engineShowTimer  = null;

const formatMoney = (amount) =>
    "$" + Number(amount).toLocaleString("en-US");

window.addEventListener("message", function(event) {
    const e = event.data;

    // ==========================================
    // PLAYER HUD
    // ==========================================
    if (e.action === "update") {
        const d = e.data;

        document.getElementById("hud").style.display = "flex";
        document.getElementById("player-info-hud").style.display = "flex";

        // Player Info
        if (d.pId   !== undefined) document.getElementById("player-id").innerText   = d.pId;
        if (d.pName !== undefined) document.getElementById("player-name").innerText = d.pName;
        if (d.pJob  !== undefined) document.getElementById("player-job").innerText  = d.pJob;
        if (d.pCash !== undefined) document.getElementById("player-cash").innerText = formatMoney(d.pCash);
        if (d.pBank !== undefined) document.getElementById("player-bank").innerText = formatMoney(d.pBank);

        // Sağlık / Zırh
        document.getElementById("health-fill").style.width = d.health + "%";
        document.getElementById("armor-fill").style.width  = d.armor  + "%";

        // Açlık / Susuzluk
        document.getElementById("hunger-fill").style.width = d.hunger + "%";
        document.getElementById("thirst-fill").style.width = d.thirst + "%";
        document.getElementById("hunger-icon").style.color = d.hunger < 20 ? "red" : "rgba(255,255,255,0.7)";
        document.getElementById("thirst-icon").style.color = d.thirst < 20 ? "red" : "rgba(255,255,255,0.7)";

        // Stamina
        const staminaCont = document.getElementById("stamina-container");
        if (d.stamina < 100) {
            staminaCont.style.display = "flex";
            document.getElementById("stamina-fill").style.width  = d.stamina + "%";
            document.getElementById("stamina-icon").style.color  = d.stamina < 20 ? "red" : "white";
        } else {
            staminaCont.style.display = "none";
        }

        // Oksijen
        const oxyCont = document.getElementById("oxygen-container");
        if (d.isUnderwater) {
            oxyCont.style.display = "flex";
            document.getElementById("oxygen-fill").style.width = d.oxygen + "%";
            document.getElementById("oxygen-icon").style.color = d.oxygen < 20 ? "red" : "white";
        } else {
            oxyCont.style.display = "none";
        }

        // Mikrofon
        const mic     = document.getElementById("mic-bg");
        const micIcon = document.getElementById("mic-icon");

        let fill = 33;
        if (d.voice <= 1)      fill = 33;
        else if (d.voice == 2) fill = 66;
        else if (d.voice >= 3) fill = 100;

        micIcon.className = d.isRadio ? "fa-solid fa-walkie-talkie" : "fa-solid fa-microphone";

        if (d.isTalking || d.isRadio) {
            micIcon.style.color = d.isRadio ? "#e74c3c" : "#b026ff";
            mic.style.background = `linear-gradient(to top, rgba(176,38,255,0.4) ${fill}%, rgba(15,15,15,0.85) ${fill}%)`;
        } else {
            micIcon.style.color = "white";
            mic.style.background = `linear-gradient(to top, rgba(255,255,255,0.2) ${fill}%, rgba(15,15,15,0.85) ${fill}%)`;
        }

        // Stres
        const stressBg   = document.getElementById("stress-bg");
        const stressIcon = document.getElementById("stress-icon");
        if (d.showStress && d.stress > 0) {
            stressBg.style.display    = "flex";
            stressBg.style.background = `linear-gradient(to top, rgba(231,76,60,0.4) ${d.stress}%, rgba(15,15,15,0.85) ${d.stress}%)`;
            stressIcon.style.color    = d.stress > 50 ? "#e74c3c" : "white";
        } else {
            stressBg.style.display = "none";
        }

        // Kanama
        const bleedCont = document.getElementById("bleed-container");
        if (d.bleed) {
            bleedCont.style.display    = "flex";
            bleedCont.style.background = `linear-gradient(to top, rgba(139,0,0,0.6) ${d.bleedLevel}%, rgba(15,15,15,0.85) ${d.bleedLevel}%)`;
            if (d.bleedLevel > 80) {
                bleedCont.classList.add("bleed-critical");
            } else {
                bleedCont.classList.remove("bleed-critical");
            }
        } else {
            bleedCont.style.display = "none";
            bleedCont.classList.remove("bleed-critical");
        }

        // Kemik kırığı
        document.getElementById("bone-container").style.display   = d.bone    ? "flex" : "none";
        document.getElementById("devmode-container").style.display = d.devmode ? "flex" : "none";

        // Durum ayracı
        const hasStatus = (d.showStress && d.stress > 0) || d.bleed || d.bone || d.devmode;
        document.getElementById("status-separator").style.display = hasStatus ? "block" : "none";

        // Crosshair
        document.getElementById("crosshair").style.display = d.isAiming ? "block" : "none";

        // Silah
        const weaponCont = document.getElementById("weapon-container");
        if (d.hasWeapon) {
            weaponCont.style.display = "flex";
            document.getElementById("ammo-clip").innerText  = d.ammoClip;
            document.getElementById("ammo-total").innerText = d.ammoTotal;
        } else {
            weaponCont.style.display = "none";
        }
    }

    // ==========================================
    // GİZLE
    // ==========================================
    else if (e.action === "hide") {
        document.getElementById("hud").style.display             = "none";
        document.getElementById("player-info-hud").style.display = "none";
        document.getElementById("stamina-container").style.display = "none";
        document.getElementById("oxygen-container").style.display  = "none";
        document.getElementById("weapon-container").style.display   = "none";
        document.getElementById("crosshair").style.display          = "none";
    }

    // ==========================================
    // SİNEMATİK
    // ==========================================
    else if (e.action === "cinematicBars") {
        document.getElementById("cinematic-top").style.height    = e.state ? "12vh" : "0";
        document.getElementById("cinematic-bottom").style.height = e.state ? "12vh" : "0";
    }

    // ==========================================
    // ARAÇ HUD
    // ==========================================
    else if (e.action === "updateCarHud") {
        document.getElementById("vehicle-hud").style.display = "flex";

        // Elektrik / Benzin
        const fuelTypeIcon = document.getElementById("fuel-type-icon");
        const rpmPath      = document.getElementById("rpm-path");
        if (e.isElectric) {
            rpmPath.style.stroke    = "url(#elec-grad)";
            fuelTypeIcon.className  = "fa-solid fa-plug";
        } else {
            rpmPath.style.stroke    = "url(#gas-grad)";
            fuelTypeIcon.className  = "fa-solid fa-gas-pump";
        }

        // RPM
        rpmPath.style.strokeDashoffset = 100 - (e.rpm * 100);

        // Hız
        const speedStr = e.speed.toString().padStart(3, "0");
        let speedHtml  = "";
        let foundNonZero = false;
        for (let i = 0; i < speedStr.length; i++) {
            if (speedStr[i] === "0" && !foundNonZero && i < speedStr.length - 1) {
                speedHtml += `<span class="faded-zero">0</span>`;
            } else {
                foundNonZero = true;
                speedHtml += speedStr[i];
            }
        }
        document.getElementById("veh-speed").innerHTML = speedHtml;
        document.getElementById("veh-gear").innerText  = e.gear;

        // Yakıt
        const fuelPath = document.getElementById("fuel-path");
        fuelPath.style.strokeDashoffset = 100 - e.fuel;
        fuelPath.style.stroke = e.fuel <= 20 ? "#e74c3c" : "#ffffff";

        // Işıklar
        const lightsIcon = document.getElementById("icon-lights");
        lightsIcon.classList.toggle("active-lights", e.lights);

        // Yakıt uyarı ikonu
        document.getElementById("icon-fuel").classList.toggle("active-fuel", e.fuel < 15);

        // Emniyet Kemeri
        const seatbeltIcon = document.getElementById("icon-seatbelt");
        if (e.seatbelt) {
            seatbeltIcon.classList.remove("active-seatbelt");
            seatbeltIcon.classList.add("seatbelt-on");
            seatbeltIcon.innerHTML = '<i class="fa-solid fa-user-check"></i>';
        } else {
            seatbeltIcon.classList.remove("seatbelt-on");
            seatbeltIcon.classList.add("active-seatbelt");
            seatbeltIcon.innerHTML = '<i class="fa-solid fa-user-slash"></i>';
        }

        // Kilit
        const lockIcon = document.getElementById("icon-lock");
        if (e.locked) {
            lockIcon.classList.remove("unlocked");
            lockIcon.classList.add("locked");
            lockIcon.innerHTML = '<i class="fa-solid fa-lock"></i>';
        } else {
            lockIcon.classList.remove("locked");
            lockIcon.classList.add("unlocked");
            lockIcon.innerHTML = '<i class="fa-solid fa-unlock"></i>';
        }

        // Nitro
        const nitroPath = document.getElementById("nitro-path");
        const nitroBg   = document.getElementById("nitro-bg");
        if (e.nitro && e.nitro > 0) {
            if (nitroPath) nitroPath.style.display = "block";
            if (nitroBg)   nitroBg.style.display   = "block";
            if (nitroPath) {
                nitroPath.style.strokeDashoffset = 100 - e.nitro;
                nitroPath.style.stroke = e.purge >= 100 ? "#ff0000" : "#00d0ff";
            }
        } else {
            if (nitroPath) nitroPath.style.display = "none";
            if (nitroBg)   nitroBg.style.display   = "none";
        }

        // Motor Sağlığı
        const engineContainer = document.getElementById("engine-container");
        const isDamagedNow    = e.engine < lastEngineHealth && e.engine < 995;
        lastEngineHealth      = e.engine;

        if (e.engine < 995) {
            const enginePct = Math.max(0, Math.min(100, (e.engine / 1000) * 100));
            document.getElementById("engine-fill").style.width  = enginePct + "%";
            document.getElementById("engine-icon").style.color  = enginePct <= 10 ? "#e74c3c" : "white";

            if (enginePct <= 10) {
                engineContainer.style.display = "flex";
                if (engineShowTimer) clearTimeout(engineShowTimer);
            } else if (isDamagedNow) {
                engineContainer.style.display = "flex";
                if (engineShowTimer) clearTimeout(engineShowTimer);
                engineShowTimer = setTimeout(() => {
                    if (lastEngineHealth > 100) {
                        engineContainer.style.display = "none";
                    }
                }, 3000);
            }
        } else {
            engineContainer.style.display = "none";
            if (engineShowTimer) clearTimeout(engineShowTimer);
        }
    }

    // ==========================================
    // ARAÇ HUD GİZLE
    // ==========================================
    else if (e.action === "hideCarHud") {
        document.getElementById("vehicle-hud").style.display    = "none";
        document.getElementById("engine-container").style.display = "none";
        lastEngineHealth = 1000;
    }

    // ==========================================
    // PUSULA / COMPASS
    // ==========================================
    else if (e.action === "updateCompass") {
        const compassCont = document.getElementById("compass-container");
        compassCont.style.display = "flex";

        document.getElementById("degree").innerText = e.heading;
        document.getElementById("street").innerText = e.street;
        document.getElementById("zone").innerText   = e.zone;

        const waypointBox = document.getElementById("waypoint-box");
        if (e.waypoint) {
            waypointBox.style.display = "flex";
            document.getElementById("waypoint-dist").innerText = e.waypoint;

            const dirMap = { up: "fa-arrow-up", down: "fa-arrow-down", left: "fa-arrow-left", right: "fa-arrow-right" };
            document.querySelector("#waypoint-box i").className = "fa-solid " + (dirMap[e.waypointDir] || "fa-arrow-up");
        } else {
            waypointBox.style.display = "none";
        }

        document.getElementById("compass-letters").style.transform = `rotate(${-e.heading}deg)`;
        document.querySelectorAll(".letter").forEach(letter => {
            letter.style.transform = `translate(-50%, -50%) rotate(${e.heading}deg)`;
        });
    }

    else if (e.action === "hideCompass") {
        document.getElementById("compass-container").style.display = "none";
    }

    // ==========================================
    // SAFEZONE UYARISI
    // ==========================================
    else if (e.action === "showSafezoneWarning") {
        document.getElementById("safezone-warning").style.display = "flex";
    }
    else if (e.action === "hideSafezoneWarning") {
        document.getElementById("safezone-warning").style.display = "none";
    }

    // ==========================================
    // HUD MENÜSÜ (/hud)
    // ==========================================
    else if (e.action === "openHudMenu") {
        setRow("map", e.map);
        setRow("cinematic", e.cinematic);
        setRow("dev", e.dev);
        document.getElementById("hm-dev-row").style.display = e.isAdmin ? "flex" : "none";
        document.getElementById("hud-menu").style.display = "flex";
    }
    else if (e.action === "closeHudMenu") {
        document.getElementById("hud-menu").style.display = "none";
    }
});

function setRow(key, on) {
    const row = document.querySelector('.hm-row[data-key="' + key + '"]');
    if (row) row.classList.toggle("on", !!on);
}

function nui(name, data) {
    return fetch("https://" + GetParentResourceName() + "/" + name, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(data || {})
    }).then(r => r.json()).catch(() => ({}));
}

document.querySelectorAll(".hm-row").forEach(function(row) {
    row.addEventListener("click", function() {
        nui("hudToggle", { key: row.dataset.key }).then(function(res) {
            if (res && typeof res.state === "boolean") setRow(row.dataset.key, res.state);
        });
    });
});
document.getElementById("hm-close").addEventListener("click", function() { nui("hudClose"); });
document.addEventListener("keydown", function(ev) {
    if (ev.key === "Escape" && document.getElementById("hud-menu").style.display === "flex") nui("hudClose");
});
