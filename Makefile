PROJECT = help

$(PROJECT).prg: $(PROJECT).asm bios.inc
	asm02 -l -L $(PROJECT).asm
	link02 -e $(PROJECT).prg -o $(PROJECT).bin

hex: $(PROJECT).prg
	cat $(PROJECT).prg | ../../tointel.pl > $(PROJECT).hex

bin: $(PROJECT).prg
	../../tobinary $(PROJECT).prg

install: $(PROJECT).prg
	cp $(PROJECT).prg ../../..
	cd ../../.. ; ./run -R $(PROJECT).prg

clean:
	-rm $(PROJECT).prg


