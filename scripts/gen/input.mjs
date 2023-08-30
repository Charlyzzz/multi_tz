import * as fs from "fs";


const timezonesInput = JSON.parse(fs.readFileSync("data/timezones.json").toString()).timezones;
const aliases = JSON.parse(fs.readFileSync("data/aliases.json").toString());


const timezones = timezonesInput.reduce((timezonesSoFar, timezone) => {
    const {utc, offset, abbr} = timezone;
    timezonesSoFar[abbr] = offset;

    utc.forEach(utcAbbr => {
        timezonesSoFar[utcAbbr] = offset;
    });
    return timezonesSoFar;
}, {});


Object.entries(aliases).reduce((timezonesSoFar, [alias, timezoneName]) => {
    const source = timezonesSoFar[timezoneName];
    if(source === undefined) {
        throw new Error(`Cannot alias ${alias}: ${timezoneName} is not a known timezone`);
    }
    timezonesSoFar[alias] = source;
    return timezonesSoFar;
}, timezones);

function sortByOffset([, offsetA], [, offsetB]) {
    return offsetA - offsetB;
}

const out = Object.entries(timezones).sort(sortByOffset).map(([name, offset]) => {
    return `.{"${name}", ${offset}}`;
}).join(",\n");

fs.writeFileSync("zig-int", out);