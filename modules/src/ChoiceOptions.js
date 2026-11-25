.pragma library

function value(option)
{
    return option !== null && typeof option === "object" ? option.value : option;
}

function label(option)
{
    return String(option !== null && typeof option === "object" ? option.label : option);
}

function unique(options)
{
    const seen = new Set();
    return options.filter(option => {
        const key = String(value(option));
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
    });
}

function indexOf(options, current)
{
    return options.findIndex(option => String(value(option)) === String(current));
}
