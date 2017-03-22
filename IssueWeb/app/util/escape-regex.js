export default function escapeStringForRegex(s) {
    return s.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
}
