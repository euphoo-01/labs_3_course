const util = require('util');
const events = require('events');

var db_data = [
    { id: 1, name: 'Beloded N.I.',  bday: '2001-01-01' },
    { id: 2, name: 'Smelov V.V.',  bday: '2001-01-02' },
    { id: 3, name: 'Shiman D.V.', bday: '2001-01-03' }
];

function DB() {
    events.EventEmitter.call(this);

    this.select = () => {
        return db_data;
    };

    this.insert = (row) => {
        db_data.push(row);
        return row;
    };

    this.update = (row) => {
        var index = db_data.findIndex((item) => item.id === row.id);

        if (index === -1) {
            return null;
        }

        db_data[index] = row;
        return row;
    };

    this.delete = (id) => {
        var index = db_data.findIndex((item) => item.id === id);

        if (index === -1) {
            return null;
        }

        return db_data.splice(index, 1)[0];
    };

    this.commit = () => {};
}

util.inherits(DB, events.EventEmitter);

module.exports = DB;
